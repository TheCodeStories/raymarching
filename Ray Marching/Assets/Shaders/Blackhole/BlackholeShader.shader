Shader "Hidden/BlackholeShader"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _CubeMap ("Skybox", CUBE) = "" {}
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
            #include "../DistanceFunctions.cginc"

            sampler2D _MainTex;
            sampler2D _DiskNoise;
            samplerCUBE _CubeMap;
            uniform sampler2D _CameraDepthTexture;
            uniform float4x4 _CamFrustum, _CamToWorld;
            uniform float _MaxDistance;
            uniform float4 _Sphere;
            uniform float4 _SphereColor;
            uniform int _MaxIterations;
            uniform float _Accuracy;
            uniform float _StepSize;

            //Black Hole parameters
            uniform float _BlackHoleMass;
            uniform float3 _Cylinder;
            uniform float3 _CylinderColor;
            uniform float _RotationSpeed;

            //Glow parameters
            uniform float4 _MainGlowColor;
            uniform float _MainGlowWidth;
            uniform float _MainGlowSharpness;
            uniform float4 _OuterGlowColor;
            uniform float _OuterGlowWidth;
            uniform float _OuterGlowSoftness;
            uniform float _GlowIntensity;
            uniform float _GlowLimit;



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

            float hash(float3 p) {
                p = frac(p * 0.3183099 + 0.1);
                p *= 17.0;
                return frac(p.x * p.y * p.z * (p.x + p.y + p.z));
            }

            float noise(float3 x) {
                float3 i = floor(x);
                float3 f = frac(x);
                f = f * f * (3.0 - 2.0 * f);
                return lerp(lerp(lerp(hash(i + float3(0, 0, 0)), 
                                hash(i + float3(1, 0, 0)), f.x),
                            lerp(hash(i + float3(0, 1, 0)), 
                                hash(i + float3(1, 1, 0)), f.x), f.y),
                        lerp(lerp(hash(i + float3(0, 0, 1)), 
                                hash(i + float3(1, 0, 1)), f.x),
                            lerp(hash(i + float3(0, 1, 1)), 
                                hash(i + float3(1, 1, 1)), f.x), f.y), f.z);
            }

            // float4 sdf(float3 position)
            // {
            //     float4 cylinder = float4(_CylinderColor.rgb, sdHollowCylinder(position - _Sphere.xyz, _Cylinder));
                
            //     if(cylinder.w < _GlowLimit)
            //     {
            //         float time = _Time.y; // Unity built-in time variable
            //         float3 c = float3(
            //             length(-position),
            //             -position.y,
            //             atan2(-position.z + 1.0, -position.x + 1.0) + time * _RotationSpeed
            //         );
            //         c *= 10.0;
            //         cylinder.w += noise(c) * 0.4;
            //         cylinder.w += noise(c * 2.5) * 0.2;
            //     }
                
            //     return cylinder;
            // }


            // #define TILE_SIZE 8.0

            // float hash(float3 p) {
            //     p = frac(p * 0.3183099 + 0.1);
            //     p *= 17.0;
            //     return frac(p.x * p.y * p.z * (p.x + p.y + p.z));
            // }

            // float noise(float3 x) {
            //     float3 i = floor(x);
            //     float3 f = frac(x);
            //     f = f * f * (3.0 - 2.0 * f);

            //     // Wrap lattice coords to TILE_SIZE to repeat the pattern
            //     float3 wrap = TILE_SIZE;

            //     float3 i0 = fmod(i, wrap);
            //     float3 i1 = fmod(i + 1.0, wrap);

            //     return lerp(
            //         lerp(
            //             lerp(hash(i0 + float3(0, 0, 0)), hash(float3(i1.x, i0.y, i0.z)), f.x),
            //             lerp(hash(float3(i0.x, i1.y, i0.z)), hash(float3(i1.x, i1.y, i0.z)), f.x),
            //             f.y),
            //         lerp(
            //             lerp(hash(float3(i0.x, i0.y, i1.z)), hash(float3(i1.x, i0.y, i1.z)), f.x),
            //             lerp(hash(float3(i0.x, i1.y, i1.z)), hash(float3(i1.x, i1.y, i1.z)), f.x),
            //             f.y),
            //         f.z);
            // }
            // float4 sdf(float3 position)
            // {
            //     float4 cylinder = float4(_CylinderColor.rgb, sdHollowCylinder(position - _Sphere.xyz, _Cylinder));
                
            //     if (cylinder.w < _GlowLimit)
            //     {
            //         float time = _Time.y;
            //         float radius = length(-position);

            //         float angle = atan2(-position.z + 1.0, -position.x + 1.0);
            //         float speed = _RotationSpeed / sqrt(radius + 0.001); // realistic shear
            //         angle += time * speed;

            //         float3 c = float3(radius, -position.y, angle);
            //         c *= 10.0;
            //         cylinder.w += noise(c) * 0.4;
            //         cylinder.w += noise(c * 2.5) * 0.2;
            //     }
                
            //     return cylinder;
            // }
            float4 sdf(float3 position)
            {
                float4 cylinder = float4(_CylinderColor.rgb, sdHollowCylinder(position - _Sphere.xyz, _Cylinder));
                
                if (cylinder.w < _GlowLimit)
                {
                    float time = _Time.y;
                    float radius = length(-position);
                    float angle = atan2(-position.z + 1.0, -position.x + 1.0);
                    float height = -position.y;
                    
                    float speed = _RotationSpeed / sqrt(radius + 0.001); // realistic shear
                    angle += time * speed;

                    // Use sin/cos to wrap
                    float3 c = float3(radius, height, cos(angle));
                    float3 d = float3(radius, height, sin(angle));

                    c *= 10.0;
                    d *= 10.0;

                    cylinder.w += (noise(c) + noise(d)) * 0.2; // 0.2 to keep scale similar
                    cylinder.w += (noise(c * 2.5) + noise(d * 2.5)) * 0.1;
                }
                
                return cylinder;
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

            void RK4Step(inout float3 position, inout float3 direction, float dt)
            {
                float3 blackHoleCenter = _Sphere.xyz;

                // k1
                float3 r1 = blackHoleCenter - position;
                float dist1 = length(r1);
                float3 force1 = normalize(r1) * (_BlackHoleMass / (dist1 * dist1 + 0.001));
                float3 k1_p = direction;
                float3 k1_v = force1;

                // k2
                float3 p2 = position + 0.5 * dt * k1_p;
                float3 v2 = direction + 0.5 * dt * k1_v;
                float3 r2 = blackHoleCenter - p2;
                float dist2 = length(r2);
                float3 force2 = normalize(r2) * (_BlackHoleMass / (dist2 * dist2 + 0.001));
                float3 k2_p = v2;
                float3 k2_v = force2;

                // k3
                float3 p3 = position + 0.5 * dt * k2_p;
                float3 v3 = direction + 0.5 * dt * k2_v;
                float3 r3 = blackHoleCenter - p3;
                float dist3 = length(r3);
                float3 force3 = normalize(r3) * (_BlackHoleMass / (dist3 * dist3 + 0.001));
                float3 k3_p = v3;
                float3 k3_v = force3;

                // k4
                float3 p4 = position + dt * k3_p;
                float3 v4 = direction + dt * k3_v;
                float3 r4 = blackHoleCenter - p4;
                float dist4 = length(r4);
                float3 force4 = normalize(r4) * (_BlackHoleMass / (dist4 * dist4 + 0.001));
                float3 k4_p = v4;
                float3 k4_v = force4;

                // Combine
                position += (dt / 6.0) * (k1_p + 2.0 * k2_p + 2.0 * k3_p + k4_p);
                direction += (dt / 6.0) * (k1_v + 2.0 * k2_v + 2.0 * k3_v + k4_v);
                direction = normalize(direction);
            }

            float4 getGlow(float minPDist) {
                float mainGlow = minPDist * _MainGlowWidth;
                mainGlow = pow(mainGlow, _MainGlowSharpness);
                mainGlow = clamp(mainGlow, 0.0, 1.0);
                float outerGlow = minPDist * _OuterGlowWidth;
                outerGlow = pow(outerGlow, _OuterGlowSoftness);
                outerGlow = clamp(outerGlow, 0.0, 1.0);

                float4 glow = float4(10, 5, 3, mainGlow);
                glow += float4(0, 0, 0, outerGlow);
                
                glow.a = min(glow.a, _GlowIntensity);
                return glow;
            }


            // =======================
            // Raymarching loop with RK4
            // =======================

            fixed4 raymarching(float3 origin, float3 direction)
            {
                fixed4 result = fixed4(0.0,0.0,0.0,0.0);
                bool hit = false;

                const int maxSteps = _MaxIterations;
                const float stepSize = _StepSize;

                float3 position = origin;
                
                float glow = 0.0;

                for (int i = 0; i < maxSteps; i++) {
                    // Check hit:
                    float4 distance = sdf(position);
                    glow = max(glow, 1.0 / (distance.w + 1.0));
                    float3 bdir = normalize(-position);
                    float bdist = length(position);
                    
                    distance.w = min(distance.w, bdist) * 0.04;
                    if(distance.w > _MaxDistance) break;
                    if(bdist < 1.0){
                        float4 gcol = getGlow(glow);
                        float4 c = _SphereColor;//float4(0.0,0.0,0.0,0.0);
                        c.rgb = lerp(c.rgb, gcol.rgb, gcol.a);
                        return fixed4(c);
                    }
                    RK4Step(position, direction, stepSize);

                    // bdist = pow(bdist + 1.0, 2.0);
                    // bdist = distance.w * 1.0 / bdist;
                    // direction = lerp(direction, bdir, bdist);
                    // position += direction * max(distance.w, 0.01);
                }
                float4 c = float4(texCUBE(_CubeMap, direction).rgb * 0.1, 1.0);
                float4 gcol = getGlow(glow);
                c.rgb = lerp(c.rgb, gcol.rgb, gcol.a);
                return fixed4(c);
            }


            fixed4 frag (v2f i) : SV_Target
            {
                fixed3 color = tex2D(_MainTex, i.uv);
                float3 rayDirection = normalize(i.ray.xyz);
                float3 rayOrigin = _WorldSpaceCameraPos;
                fixed4 result = raymarching(rayOrigin, rayDirection);

                return fixed4(result.rgb, 1.0);

                // return fixed4(color * (1.0 - result.w) + result.rgb * result.w, 1.0);
            }
            ENDCG
        }
    }
}


