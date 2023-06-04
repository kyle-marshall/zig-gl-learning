#version 410 core
out vec4 FragColor;
in vec3 ourColor;
in vec2 TexCoord;

uniform sampler2D tex0;
uniform sampler2D tex1;

void main()
{
    FragColor = mix(mix(
            texture(tex0, TexCoord),
            texture(tex1, TexCoord), 0.4),
        vec4(ourColor, 1.0), 0.2);
}