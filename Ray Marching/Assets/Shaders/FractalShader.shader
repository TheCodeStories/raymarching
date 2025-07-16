Shader "Hidden/FractalShader"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
    }
    SubShader
    {
        // No culling or depth
        Cull Off ZWrite Off ZTest Always

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 3.0

            #include "UnityCG.cginc"
            #include "DistanceFunctions.cginc"

            sampler2D _MainTex;
            // uniform float4 _CamWorldSpace;
            uniform float4x4 _CamFrustum, _CamToWorld;
            uniform float _MaxDistance;
            uniform float3 _LightDirection;
            uniform float _Power;
            uniform float _Darkness;
            uniform int _Iterations;
            uniform float _BlackAndWhite;
            uniform float3 _ColourAMix;
            uniform float3 _ColourBMix;

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
                float3 ray : TEXCOORD1;
            };

            v2f vert (appdata v)
            {
                v2f o;
                half index = v.vertex.z;
                v.vertex.z = 0;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;

                o.ray = _CamFrustum[(int)index].xyz;

                o.ray /= abs(o.ray.z);

                o.ray = mul(_CamToWorld, o.ray);

                return o;
            }

            float2 mandelbulbDE(float3 pos)
            {
                float3 z = pos;
                float dr = 1.0;
                float r = 0.0;

                float power = _Power;
                int i;

                for (i = 0; i < _Iterations; i++)
                {
                    r = length(z);
                    if (r > 2.0) break;

                    float theta = acos(z.z / r);
                    float phi = atan2(z.y, z.x);
                    dr = pow(r, power - 1.0) * power * dr + 1.0;

                    float zr = pow(r, power);
                    theta *= power;
                    phi *= power;

                    z = zr * float3(
                        sin(theta) * cos(phi),
                        sin(phi) * sin(theta),
                        cos(theta)
                    );

                    z += pos;
                }

                float dist = 0.5 * log(r) * r / dr;
                return float2(i, dist);
            }

            float mandelboxDE(float3 z)
            {
                float3 offset = z;
                float scale = 2.0;
                float fixedRadius = 1.0;
                float minRadius = 0.5;
                float dr = 1.0;

                for (int i = 0; i < _Iterations; i++)
                {
                    // Reflect
                    z = clamp(z, -1.0, 1.0) * 2.0 - z;

                    float r2 = dot(z, z);
                    float r = length(z);

                    float scaleFactor = max(minRadius / r, min(fixedRadius / r, scale));
                    z *= scaleFactor;
                    dr *= scaleFactor;

                    z = z * scale + offset;
                    dr = dr * abs(scale) + 1.0;
                }

                return length(z) / abs(dr);
            }
            float4 sdf(float3 position)
            {
                float2 info = mandelbulbDE(position);
                float escapeIter = info.x;
                float d = info.y;
                
                float shadeA = 1.0; // Will be computed using lighting
                float shadeB = saturate(escapeIter / 16.0);

                float3 finalColor = saturate(_ColourAMix * shadeA + _ColourBMix * shadeB);

                return float4(finalColor, d);
            }


            float3 getNormal(float3 position){
                const float2 offset = float2(0.001, 0.0);
                float3 n = float3(
                    sdf(position + offset.xyy).w - sdf(position - offset.xyy).w,
                    sdf(position + offset.yxy).w - sdf(position - offset.yxy).w,
                    sdf(position + offset.yyx).w - sdf(position - offset.yyx).w
                );
                return normalize(n);
            }

            fixed4 raymarching(float3 origin, float3 direction){
                fixed4 result = fixed4(0.0,0.0,0.0,1);
                const int maxSteps = 128;
                float traveled = 0;


                for(int i = 0; i < maxSteps; i++){
                    if(traveled > _MaxDistance){
                        // result = fixed4(direction, 1);
                        break;
                    }

                    float3 position = origin + direction * traveled;
                    float4 distance = sdf(position);

                    if(distance.w < 0.1){ //We hit something
                        float3 normal = getNormal(position);

                        float light = dot(-_LightDirection, normal);

                        result = fixed4(distance.rgb * light, 1);
                    }

                    traveled += distance.w;
                }
                
                return result;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                float3 rayDirection = normalize(i.ray.xyz);
                float3 rayOrigin = _WorldSpaceCameraPos;

                // Background gradient
                float4 background = lerp(float4(51,3,20,255), float4(16,6,28,255), i.uv.y) / 255.0;

                fixed4 result = background;

                const int maxSteps = 128;
                float traveled = 0.0;
                int steps = 0;

                for (int j = 0; j < maxSteps; j++)
                {
                    float3 position = rayOrigin + rayDirection * traveled;
                    float4 d = sdf(position);

                    if (d.w < 0.01)
                    {
                        float3 normal = getNormal(position - rayDirection * 0.001);
                        float lighting = saturate(dot(normal * 0.5 + 0.5, -_LightDirection));

                        float3 color = saturate(_ColourAMix * lighting + _ColourBMix * d.rgb);
                        result = float4(color, 1.0);
                        break;
                    }

                    if (traveled > _MaxDistance) break;

                    traveled += d.w;
                    steps++;
                }

                float rim = steps / _Darkness;
                return lerp(result, 1.0, _BlackAndWhite) * rim;
            }

            ENDCG
        }
    }
}