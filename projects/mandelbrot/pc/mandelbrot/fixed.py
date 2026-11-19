"""Bit-exact model of the wide accelerator arithmetic (ROADMAP.md, phase 2, "128-bit iteration core").

Numbers are W-bit two's complement with I integer bits (sign included) and F = W - I fraction bits,
held here as Python ints in units of 2^-F. The RTL (WideSquare, WideIteration) must match this model
bit for bit; the Scala testbench has a copy of it.

One iteration, from z = (x, y) and c = (cx, cy), uses three squares of magnitudes:

    X2 = sq(|x|), Y2 = sq(|y|), S2 = sq(|x + y|)
    |z|^2 = X2 + Y2               (the escape test: |z|^2 >= R^2)
    x' = X2 - Y2 + cx             (wrapped to W bits)
    y' = S2 - X2 - Y2 + cy        (= 2xy + cy, wrapped to W bits)

A square splits its operand into 26-bit limbs (they fit the DSP blocks' 27x27 mode), multiplies only
the pairs i <= j (the cross terms doubled), and leaves out the partial products of the lowest
diagonals i + j < K. K is the largest value for which the products left out are worth less than a
quarter of the result's last bit in total. The kept products are added exactly and the sum is
shifted right by F (truncated). So a square is at most 1.25 ulp below the exact one.

No overflow: a pixel only iterates while |z| < R = 16, so z^2 + c stays below 272 when |c| < 16, and
any c with |c| >= 16 escapes at n = 1 (z_1 = c). With I = 10 the format holds +-512.

The count of a pixel is the smallest n >= 1 with |z_n|^2 >= R^2, as in protocol.py; the hardware
sees the bailout of z_n one pass later, when z_n is the input.
"""

from dataclasses import dataclass
from functools import cached_property

LIMB = 26  # bits per limb
UNRESOLVED = 0xFFFFFFFF
INTERIOR = 0xFFFFFFFE
FLAG_PERIODICITY = 1 << 0
FLAG_CARDIOID = 1 << 1

# The cardioid/bulb test (ROADMAP.md, phase 3): coordinates truncated to G fraction bits, products
# of at most 27 x 27 bits, and margins that cover every rounding, so "interior" is always right.
G = 24
CARDIOID_MARGIN = 1 << 32  # 4 * 2^-18 in units of 2^-2G
BULB_LIMIT = (1 << 44) - (1 << 27)  # 1/16 - 2^-21 in units of 2^-2G


def cardioid_bulb(x: int, y: int, f_bits: int) -> bool:
    """Whether c = (x, y) (units 2^-F) is proven inside the main cardioid or the period-2 bulb.

    X = floor(x * 2^(G-F)), Y likewise, and only -1.25 <= X < 0.5, |Y| < 0.75 is tested.
      cardioid: a = X - 1/4, Q = floor((a^2 + Y^2) / 2^G), S = Q + a:  4 Q S - Y^2 <= -2^32
      bulb:     c = X + 1:                                              c^2 + Y^2 <= 2^44 - 2^27
    (in units of 2^-G for X, Y, a, Q, S and 2^-2G for the products). The exact tests are
    q (q + x - 1/4) <= y^2 / 4 with q = (x - 1/4)^2 + y^2, and (x + 1)^2 + y^2 <= 1/16; the margins
    cover the truncation of x, y and q (error bounds in ROADMAP.md).
    """
    X = x >> (f_bits - G) if f_bits >= G else x << (G - f_bits)
    Y = y >> (f_bits - G) if f_bits >= G else y << (G - f_bits)
    if not (-5 << (G - 2) <= X < 1 << (G - 1) and -(3 << (G - 2)) < Y < 3 << (G - 2)):
        return False
    y2 = Y * Y
    a = X - (1 << (G - 2))
    q = (a * a + y2) >> G
    if 4 * q * (q + a) - y2 <= -CARDIOID_MARGIN:
        return True
    c = X + (1 << G)
    return c * c + y2 <= BULB_LIMIT


def period_refresh(n: int) -> bool:
    """The periodicity check (ROADMAP.md, phase 3) saves z_n after testing it when n has at most 3
    significant bits (n < 8, or a multiple of 2^(floor(log2 n) - 2)): four saves per octave. It
    depends on n only, never on max_it, so a run to max_it M' is a run to M > M' stopped early."""
    return (n & -n) << 3 > n


def wrap(v: int, bits: int) -> int:
    """The low `bits` bits of v as a two's complement number."""
    v &= (1 << bits) - 1
    return v - (1 << bits) if v >> (bits - 1) else v


@dataclass(frozen=True)
class WideFormat:
    w: int  # total bits
    i: int = 10  # integer bits, sign included
    r2: int = 256  # bailout radius squared (an integer)

    @property
    def f(self) -> int:
        return self.w - self.i

    @property
    def limbs(self) -> int:
        """Limbs of a square's operand: |x + y| has up to W magnitude bits."""
        return -(-self.w // LIMB)

    @cached_property
    def dropped_diagonals(self) -> int:
        """K: partial products with i + j < K are left out."""
        quarter_ulp = 1 << (self.f - 2)  # in units of the product's last bit, 2^-2F
        biggest = ((1 << LIMB) - 1) ** 2
        total, k = 0, 0
        while k <= 2 * (self.limbs - 1):
            diagonal = sum(biggest * (1 if i == k - i else 2) << (LIMB * k)
                           for i in range(self.limbs) if i <= k - i < self.limbs)
            if total + diagonal >= quarter_ulp:
                break
            total += diagonal
            k += 1
        return k

    @cached_property
    def products(self) -> list[tuple[int, int]]:
        """The limb pairs (i, j), i <= j, that are multiplied."""
        n = self.limbs
        return [(i, j) for i in range(n) for j in range(i, n) if i + j >= self.dropped_diagonals]

    def square(self, m: int) -> int:
        """The truncated square of a magnitude m >= 0 (units 2^-F in and out)."""
        assert 0 <= m < 1 << (LIMB * self.limbs)
        mask = (1 << LIMB) - 1
        limb = [(m >> (LIMB * k)) & mask for k in range(self.limbs)]
        total = 0
        for i, j in self.products:
            total += (limb[i] * limb[j] * (1 if i == j else 2)) << (LIMB * (i + j))
        return total >> self.f

    def square_exact_floor(self, m: int) -> int:
        """floor(m^2 / 2^F): the square without left-out products, for the error study."""
        return (m * m) >> self.f

    def step(self, x: int, y: int, cx: int, cy: int, square=None) -> tuple[int, int, int]:
        """One pass: (x', y', |z|^2) where |z|^2 is that of the input z (units 2^-F)."""
        sq = square or self.square
        x2, y2, s2 = sq(abs(x)), sq(abs(y)), sq(abs(x + y))
        return wrap(x2 - y2 + cx, self.w), wrap(s2 - x2 - y2 + cy, self.w), x2 + y2

    def pixel(self, cx: int, cy: int, max_it: int, square=None, periodicity=False) -> tuple[int, int]:
        """(count, |z_n|^2 at escape in units 2^-F), or (UNRESOLVED, 0), or with `periodicity`
        (INTERIOR, k): z_k equals a saved z_m (m < k) bit for bit, so the orbit repeats and never
        escapes in this arithmetic, at any max_it. The saved z starts as z_0 = 0 (period_refresh)."""
        bail = self.r2 << self.f
        x = y = 0
        sx = sy = 0
        for n in range(1, max_it + 1):
            x, y, _ = self.step(x, y, cx, cy, square)
            if periodicity:
                if x == sx and y == sy:
                    return INTERIOR, n
                if period_refresh(n):
                    sx, sy = x, y
            sq = square or self.square
            mag = sq(abs(x)) + sq(abs(y))
            if mag >= bail:
                return n, mag
        return UNRESOLVED, 0

    def mag_to_f32_bits(self, mag: int) -> int:
        """The f32 the hardware sends for |z|^2: truncated to 24 significant bits."""
        if mag == 0:
            return 0
        top = mag.bit_length() - 1
        mant = mag >> (top - 23) if top >= 23 else mag << (23 - top)
        return ((top - self.f + 127) << 23) | (mant & 0x7FFFFF)

    def record(self, cx: int, cy: int, max_it: int, flags: int = 0) -> int:
        """The 64-bit result record: count low, f32 |z|^2 high (for a proven-interior pixel the
        iteration of the proof, 0 for the cardioid test)."""
        if flags & FLAG_CARDIOID and cardioid_bulb(cx, cy, self.f):
            return INTERIOR
        count, mag = self.pixel(cx, cy, max_it, periodicity=bool(flags & FLAG_PERIODICITY))
        if count == INTERIOR:
            return (mag << 32) | INTERIOR
        return (self.mag_to_f32_bits(mag) << 32) | count
