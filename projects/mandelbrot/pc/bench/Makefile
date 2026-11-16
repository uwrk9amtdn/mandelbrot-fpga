# CPU benchmark (ROADMAP.md, phase 2 step 6). Needs g++ with OpenMP.
CXXFLAGS = -O3 -march=native -fopenmp -Wall -Wextra -std=c++17

bench: bench.cpp
	$(CXX) $(CXXFLAGS) -o $@ $<

clean:
	rm -f bench

.PHONY: clean
