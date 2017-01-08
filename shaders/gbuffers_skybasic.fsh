#version 130
#pragma optimize(on)

uniform int fogMode;

in lowp vec4 color;

/* DRAWBUFFERS:02 */
void main() {
	gl_FragData[0] = color * vec4(0.8, 0.9, 0.9, 1.0);
	if(fogMode == 9729)
		gl_FragData[0].rgb = mix(gl_Fog.color.rgb, gl_FragData[0].rgb, clamp((gl_Fog.end - gl_FogFragCoord) / (gl_Fog.end - gl_Fog.start), 0.0, 1.0));
	else if(fogMode == 2048)
		gl_FragData[0].rgb = mix(gl_Fog.color.rgb, gl_FragData[0].rgb, clamp(exp(-gl_FogFragCoord * gl_Fog.density), 0.0, 1.0));
	gl_FragData[1] = vec4(0.0);
}
