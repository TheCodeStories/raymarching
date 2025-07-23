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
            samplerCUBE _CubeMap;
            uniform sampler2D _CameraDepthTexture;
            uniform float4x4 _CamFrustum, _CamToWorld;
            uniform float _StepSize;
            uniform float _MaxDistance;
            uniform int _MaxIterations;
            uniform float _Accuracy;

            
            uniform float4 _Sphere;
            uniform float4 _SphereColor;

            //Black Hole parameters
            uniform float _BlackHoleMass;
            uniform float3 _Cylinder;
            uniform float3 _CylinderColor;
            uniform float _RotationSpeed;

            //Glow parameters
            uniform float4 _MainGlowColor;
            uniform float _MainGlowWidth;
            uniform float _MainGlowSharpness;
            uniform float _GlowIntensity;
            uniform float _GlowLimit;
            uniform float _Falloff;

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
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;

                // Reconstruct ray by interpolating frustum corners
                float3 topLeft = _CamFrustum[0].xyz;
                float3 topRight = _CamFrustum[1].xyz;
                float3 bottomRight = _CamFrustum[2].xyz;
                float3 bottomLeft = _CamFrustum[3].xyz;

                float3 top = lerp(topLeft, topRight, o.uv.x);
                float3 bottom = lerp(bottomLeft, bottomRight, o.uv.x);
                float3 ray = lerp(bottom, top, o.uv.y);

                o.ray = mul(_CamToWorld, float4(ray, 0.0)).xyz;
                o.ray = normalize(o.ray);

                return o;
            }

            float hash(float3 p) {
                p = frac(p * 0.3183099 + 0.1);
                p *= 17.0;
                return frac(sin(dot(p, float3(7, 113, 23))) * 43758.5453);
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
                    float angleCoarse = angle + time * speed;
                    float angleDetail = angle + time * speed * 3.0; // 🌀 spins 2x faster

                    // Use sin/cos to wrap
                    float3 c = float3(radius, height, cos(angleCoarse));
                    float3 d = float3(radius, height, sin(angleCoarse));
                    float3 cDetail = float3(radius, height, cos(angleDetail));
                    float3 dDetail = float3(radius, height, sin(angleDetail));

                    c *= 10.0;
                    d *= 10.0;
                    cDetail *= 10.0 * 2.5;
                    dDetail *= 10.0 * 2.5;

                    float coarse = (noise(c) + noise(d)) * 0.2;
                    float detail = (noise(cDetail) + noise(dDetail)) * 0.1;

                    cylinder.w += coarse + detail;
                    cylinder.x = coarse;
                    cylinder.y = detail;
                }
                return cylinder;
            }

            float3 computeForce(float3 pos, float3 center, float mass) {
                float3 r = center - pos;
                float d2 = dot(r, r); // cheaper than length
                return r * (mass / (sqrt(d2) * d2 + 0.001));
            }

            void RK4Step(inout float3 position, inout float3 direction, float dt) {
                float3 blackHoleCenter = _Sphere.xyz;
                float mass = _BlackHoleMass;

                float3 k1_p = direction;
                float3 k1_v = computeForce(position, blackHoleCenter, mass);

                float3 p2 = position + 0.5 * dt * k1_p;
                float3 v2 = direction + 0.5 * dt * k1_v;
                float3 k2_p = v2;
                float3 k2_v = computeForce(p2, blackHoleCenter, mass);

                float3 p3 = position + 0.5 * dt * k2_p;
                float3 v3 = direction + 0.5 * dt * k2_v;
                float3 k3_p = v3;
                float3 k3_v = computeForce(p3, blackHoleCenter, mass);

                float3 p4 = position + dt * k3_p;
                float3 v4 = direction + dt * k3_v;
                float3 k4_p = v4;
                float3 k4_v = computeForce(p4, blackHoleCenter, mass);

                position += (dt / 6.0) * (k1_p + 2.0 * k2_p + 2.0 * k3_p + k4_p);
                direction += (dt / 6.0) * (k1_v + 2.0 * k2_v + 2.0 * k3_v + k4_v);
                direction = normalize(direction);
            }
            void RK2Step(inout float3 position, inout float3 direction, float dt) {
                float3 center = _Sphere.xyz;
                float mass = _BlackHoleMass;

                float3 r1 = center - position;
                float d1_sq = dot(r1, r1);
                float3 f1 = r1 * (mass / (sqrt(d1_sq) * d1_sq + 0.001));

                float3 midPos = position + 0.5 * dt * direction;
                float3 midDir = direction + 0.5 * dt * f1;

                float3 r2 = center - midPos;
                float d2_sq = dot(r2, r2);
                float3 f2 = r2 * (mass / (sqrt(d2_sq) * d2_sq + 0.001));

                position += dt * midDir;
                direction += dt * f2;
                direction = normalize(direction);
            }

            float4 getGlow(float minPDist, float bdist, float2 noise) {
                float density = saturate(noise.x + noise.y); // comes from your swirls
                
                float t = 0.8;

                float mainGlow = minPDist * _MainGlowWidth;// * t; //* bdist;

                // Let glow scale with noise only
                mainGlow *= lerp(0.8, 1.1, density);

                // Sharpness and clamping
                float sharpness = _MainGlowSharpness;
                mainGlow = pow(mainGlow, sharpness);
                mainGlow = clamp(mainGlow, 0.0, 1.0);

                float4 glow = float4(3, 6, 12, mainGlow);
                // float4 glow = float4(2, 1, 0, mainGlow);
                // float4 glow = float4(10, 5, 3, mainGlow);
                // Fade factor: brightness decreases as bdist increases
                return glow;
            }

            // =======================
            // Raymarching loop with RK4
            // =======================

            float4 raymarching(float3 origin, float3 direction)
            {
                fixed4 result = fixed4(0.0,0.0,0.0,0.0);

                const int maxSteps = _MaxIterations;
                const float stepSize = _StepSize;

                float3 position = origin;
                
                float glow = 0.0;

                float d = 9999.0;

                for (int i = 0; i < maxSteps; i++) {
                    float4 distance = sdf(position);
                    glow = max(glow, 1.0 / (distance.w + 1.0));
                    float bdist = length(position);
                    
                    if(bdist < _Sphere.w || distance.w > _MaxDistance){
                        d = bdist;
                        break;
                    }
                    // RK2Step(position, direction, stepSize);
                    direction = normalize(direction - (position * _StepSize / pow(bdist, 3) * _BlackHoleMass));
                    position += direction * stepSize;
                }
                float4 c = 0;
                float4 gcol = 0;
                if (d < _Sphere.w){
                    c = _SphereColor;
                    gcol = getGlow(glow, length(position), sdf(position).xy);
                }
                else{
                    c = float4(texCUBE(_CubeMap, direction).rgb * 0.1, 1.0);
                    gcol = getGlow(glow, length(position), float2(1.0, 1.0));
                }
                // c.rgb = lerp(c.rgb, gcol.rgb, gcol.a);
                c.rgb += gcol.rgb * gcol.a; // additive, keeps HDR

                return float4(c);
            }


            float4 frag (v2f i) : SV_Target
            {
                fixed3 color = tex2D(_MainTex, i.uv);
                float3 rayDirection = normalize(i.ray.xyz);
                float3 rayOrigin = _WorldSpaceCameraPos;
                float4 result = raymarching(rayOrigin, rayDirection);

                return float4(result.rgb, 1.0);
            }
            ENDCG
        }
    }
}


