// Copyright 2017 Cheng Cao, under THE APACHE LICENSE

vec2 normalEncode(vec3 n) {
	vec2 enc = normalize(n.xy) * (sqrt(-n.z*0.5+0.5));
	enc = enc*0.5+0.5;
	return enc;
}

#define VSH void main()
