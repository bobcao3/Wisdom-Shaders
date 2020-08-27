vec3 N = vec3(2.0), K = vec3(2.0);

if (match(metalic, 230.0 / 255.0))
{
    // Iron
    N = vec3(2.9114, 2.9497, 2.5845);
    K = vec3(3.0893, 2.9318, 2.7670);
}
else if (match(metalic, 231.0 / 255.0))
{
    // Gold
    N = vec3(0.20152, 0.3483, 1.3654);
    K = vec3(3.1538, 2.4204, 1.7520);
}
else if (match(metalic, 232.0 / 255.0))
{
    // Aluminum
    N = vec3(1.3456, 0.96521, 0.61722);
    K = vec3(7.4746, 6.3995, 5.3031);
}
else if (match(metalic, 233.0 / 255.0))
{
    // Chrome
    N = vec3(3.1071, 3.1812, 2.3230);
    K = vec3(3.3314, 3.3291, 3.1350);
}
else if (match(metalic, 234.0 / 255.0))
{
    // Copper
    N = vec3(0.27105, 0.67693, 1.3164);
    K = vec3(3.6092, 2.6248, 2.2921);
}
else if (match(metalic, 235.0 / 255.0))
{
    // Lead
    N = vec3(1.9100, 1.8300, 1.4400);
    K = vec3(3.5100, 3.4000, 3.1800);
}
else if (match(metalic, 236.0 / 255.0))
{
    // Platinum
    N = vec3(2.3757, 2.0847, 1.8453);
    K = vec3(4.2655, 3.7153, 3.1365);
}
else if (match(metalic, 237.0 / 255.0))
{
    // Silver
    N = vec3(0.15943, 0.14512, 0.13547);
    K = vec3(3.9291, 3.1900, 2.3808);
}
else if (match(metalic, 1.0))
{
    // Water
    N = vec3(1.2);
    K = vec3(1.0);
}