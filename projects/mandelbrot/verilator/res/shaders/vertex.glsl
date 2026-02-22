#version 450 core

out vec2 pos;

vec2 pts[4] = {
    vec2(-1.0,  1.0),
    vec2( 1.0,  1.0),
    vec2(-1.0, -1.0),
    vec2( 1.0, -1.0)
};

void main()
{
    pos = pts[gl_VertexID];

    gl_Position = vec4(pos, 0, 1);
}
