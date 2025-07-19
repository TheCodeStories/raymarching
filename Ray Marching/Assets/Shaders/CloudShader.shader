Shader "Hidden/CloudShader"
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
            uniform sampler2D _CameraDepthTexture;
            uniform float4x4 _CamFrustum, _CamToWorld;
            uniform float _MaxDistance;
            uniform float4 _Sphere;
            uniform float4 _SphereColor;
            uniform float _SmoothFactor;
            uniform float _BlendFactor;
            uniform int _MaxIterations;
            uniform float _Accuracy;

            uniform float _Density;
            uniform float _StepSize;
            uniform float _ShadowStepSize;

            uniform float3 _LightPosition;
            uniform float3 _LightColor;
            uniform float _LightIntensity;
            uniform float _AnisotropyForward;   // e.g. 0.6
            uniform float _AnisotropyBackward;  // e.g. -0.3
            uniform float _LobeWeight;          // e.g. 0.75
            uniform float _ExponentialFactor;

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

            float4 sdf(float3 position)
            {
                float4 sphere = float4(_SphereColor.rgb, sdSphere(position - _Sphere.xyz, _Sphere.w));
                // float4 box = float4(0.0, 1.0, 0.0, sdBox(position, _Sphere.w));
                float4 box = float4(1.0, 1.0, 1.0, sdBox(position, _Sphere.w));
                // float4 torus = float4(
                //     _SphereColor.rgb, 
                //     sdTorus(
                //         position - _Sphere.xyz, 
                //         float2(2, 0.75)
                //     )
                // );
                // float4 torus = float4(
                //     _SphereColor.rgb, 
                //     sdTorusFlattened(
                //         position - _Sphere.xyz, 
                //         float3(10, 2,3)
                //     )
                // );

                return smoothMin(sphere, box, 1.0);
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

            float sampleDensity(float3 pos) {
                return _Density;
                // float noise = snoise(pos * 2.0);
                // return saturate(noise) * _Density;
            }

            float computeTransmittance(float3 position, float3 lightDir, float lightDistance) {
                float transmittance = 1.0;
                const float shadowStepSize = _ShadowStepSize; // or make it a uniform
                int steps = lightDistance / (shadowStepSize + 0.01);

                if(steps > 100){
                    steps = 100;
                }

                for (int i = 0; i < steps; i++) {
                    float3 samplePos = position + lightDir * (i * shadowStepSize);
                    float density = sampleDensity(samplePos);
                    // transmittance *= exp(-density * shadowStepSize);
                    transmittance *= exp(-pow(density, _ExponentialFactor) * shadowStepSize);

                    if (transmittance < 0.01) break;
                }

                return transmittance;
            }

            float HG(float g, float cosTheta) {
                float denom = 1.0 + g * g - 2.0 * g * cosTheta;
                return (1.0 - g * g) / (4.0 * UNITY_PI * pow(denom, 1.5));
            }

            float doubleLobedHG(float cosTheta, float g1, float g2, float w) {
                return w * HG(g1, cosTheta) + (1.0 - w) * HG(g2, cosTheta);
            }

            fixed4 raymarching(float3 origin, float3 direction, float depth){
                const int maxSteps = _MaxIterations;
                float traveled = 0;

                float3 accumColor = float3(0,0,0);
                float transmittance = 1.0;

                bool insideNeverTrue = true;
                bool inside = false;
                float entryDistance = 0;

                for(int i = 0; i < maxSteps; i++){
                    float3 position = origin + direction * traveled;
                    float4 distance = sdf(position);
                    float dist = distance.w;

                    if(!inside && abs(dist) < _Accuracy){
                        // Just entered the volume
                        inside = true;
                        insideNeverTrue = false;
                        entryDistance = traveled;
                    }
                    else if(inside && dist > _Accuracy){
                        // Just exited the volume
                        float exitDistance = traveled;
                        float segmentLength = exitDistance - entryDistance;

                        const int steps = (segmentLength / _StepSize) + 1;

                        for(int j = 0; j < steps; j++){
                            float t = entryDistance + j * _StepSize;
                            float3 pos = origin + direction * t;

                            float density = sampleDensity(pos); // optionally sample noise

                            float3 lightDir = normalize(_LightPosition - pos);
                            float lightDistance = length(_LightPosition - pos);

                            float lightTrans = computeTransmittance(pos, lightDir, lightDistance);

                            float3 viewDir = -direction; // from sample point to camera
                            float cosTheta = dot(lightDir, viewDir);

                            // Use double-lobed HG
                            float phase = doubleLobedHG(cosTheta, _AnisotropyForward, _AnisotropyBackward, _LobeWeight);

                            float3 scatteredLight = lightTrans * _LightColor * _LightIntensity * phase;
                            float scattering = density * _StepSize;

                            accumColor += transmittance * scatteredLight * scattering * distance.rgb;
                            // transmittance *= exp(-density * _StepSize); 
                            transmittance *= exp(-pow(density, _ExponentialFactor) * _StepSize);



                            if(transmittance < 0.01) break;
                        }

                        inside = false;
                    }

                    traveled += inside ? _StepSize : dist;
                    if(transmittance < 0.01) break;
                }

                return fixed4(accumColor, 1.0 - transmittance);

            }

            fixed4 frag (v2f i) : SV_Target
            {
                float depth = LinearEyeDepth(tex2D(_CameraDepthTexture, i.uv).r);
                depth *= length(i.ray);
                float nearEstimate = 0.5; // or 1.0 if your clouds start further away
                float farEstimate = 50.0; // Or 100+ for very distant volumes

                if (depth < nearEstimate || depth > farEstimate) discard;

                fixed3 color = tex2D(_MainTex, i.uv); //BACKGROUND
                // fixed3 color = fixed3(0.0, 0.0, 0.0);
                float3 rayDirection = normalize(i.ray.xyz);
                float3 rayOrigin = _WorldSpaceCameraPos;
                fixed4 result = raymarching(rayOrigin, rayDirection, depth);
                
                return fixed4(color * (1.0 - result.w) + result.rgb * result.w, 1.0);
            }
            ENDCG
        }
    }
}