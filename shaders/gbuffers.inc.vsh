// Copyright 2017 Cheng Cao, under THE APACHE LICENSE

vec2 normalEncode(vec3 n) {
    return vec2(n.xy * inversesqrt(n.z * 8.0 + 8.0) + 0.5);
}

#define VSH void main()
