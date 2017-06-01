// Copyright 2017 Cheng Cao, under THE APACHE LICENSE

vec2 normalEncode(vec3 n) {return sqrt(-n.z*0.125+0.125) * normalize(n.xy) + 0.5;}

#define VSH void main()
