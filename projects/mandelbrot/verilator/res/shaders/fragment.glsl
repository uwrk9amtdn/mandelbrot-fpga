#version 450 core

layout(std430, binding = 3) buffer data
{
    uint iter[];
};

layout (location = 1) uniform uint m;
layout (location = 2) uniform uint SX;
layout (location = 3) uniform uint SY;

in  vec2 pos;
out vec4 color;

void main()
{
    uint x = uint((pos.x + 1.0) / 2.0 * SX);
    uint y = uint((pos.y + 1.0) / 2.0 * SY);

    float c = float(iter[y*SX+x]) / m;
    color = vec4(1 - c, 0, 0, 1);

}
