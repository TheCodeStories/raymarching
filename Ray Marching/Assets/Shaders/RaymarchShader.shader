Shader "Hidden/RaymarchShader"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
    }
    SubShader
    {
        Cull Off ZWrite Off ZTest Always

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 3.0

            #include "UnityCG.cginc"
            #include "Utils.cginc"

            sampler2D _MainTex;
            uniform sampler2D _CameraDepthTexture;
            uniform float4x4 _CamFrustum, _CamToWorld;

            uniform int _MaxIterations;
            uniform float _MaxDistance;
            uniform float _Accuracy;

            uniform float4 _Sphere;
            uniform float4 _SphereColor;
            uniform float4 _Sphere2;
            uniform float4 _Sphere2Color;
            uniform float3 _Box;
            uniform float3 _BoxBounds;
            uniform float4 _BoxColor;
            uniform float3 _Box2;
            uniform float3 _Box2Bounds;
            uniform float4 _Box2Color;
            uniform float3 _Box3;
            uniform float3 _Box3Bounds;
            uniform float4 _Box3Color;

            uniform float3 _LightDirection;
            uniform float3 _LightColor;
            uniform float _LightIntensity;
            uniform float _ShadowIntensity;
            uniform float _ShadowPenumbra;
            uniform float2 _ShadowDistance;

            uniform int _ColorEnabled;
            uniform int _ShadowEnabled;
            uniform int _BackgroundEnabled;

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

            float sDSphere(float3 position, float radius)
            {
                return length(position) - radius;
            }

            float sdBoxRot(float3 position, float3 bounds, float angleY)
            {
                angleY = radians(-angleY);
                float c = cos(-angleY); 
                float s = sin(-angleY);

                float3 rotatedPos;
                rotatedPos.x = c * position.x - s * position.z;
                rotatedPos.y = position.y;
                rotatedPos.z = s * position.x + c * position.z;

                float3 q = abs(rotatedPos) - bounds;
                return length(max(q, 0.0)) + min(max(q.x, max(q.y, q.z)), 0.0);
            }
            
            float4 opUS(float4 d1, float4 d2, float k){
                float h = clamp(0.5 + 0.5 + (d2.w - d1.w) / k, 0.0, 1.0);
                float3 color = lerp(d2.rgb, d1.rgb, h);
                float distance = lerp(d2.w, d1.w, h) - k * h * (1.0 - h);
                return float4(color, distance);
            }

            float4 sdf(float3 position)
            {
                float4 sphere = float4(_SphereColor.rgb, sDSphere(position - _Sphere.xyz, _Sphere.w));
                float4 sphere2 = float4(_Sphere2Color.rgb, sDSphere(position - _Sphere2.xyz, _Sphere2.w));

                float4 box1 = float4(_BoxColor.rgb, sdBox(position - _Box.xyz, _BoxBounds));
                float4 box2 = float4(_Box2Color.rgb, sdBoxRot(position - _Box2.xyz, _Box2Bounds, 200.0));
                float4 box3 = float4(_Box3Color.rgb, sdBox(position - _Box3.xyz, _Box3Bounds));

                return smoothMin(
                    smoothMin(
                        smoothMin(
                            smoothMin(
                                sphere,
                                sphere2,
                                0.0
                            ),
                            box1,
                            0.0
                        ),
                        box2,
                        0.0
                    ),
                    box3,
                    0.0
                );
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

            float softShadow(float3 ro, float3 rd, float minTraveled, float maxTraveled, float k){
                float result = 1.0;
                for(float traveled = minTraveled; traveled < maxTraveled;){
                    float h = sdf(ro + rd * traveled).w; 
                    if(h < 0.001){
                        return 0.0;
                    }
                    result = min(result, k * h/traveled);
                    traveled += h; 
                }
                return clamp(result, 0.0, 1.0);
            }

            float3 shading(float3 position, float3 normal, float3 color){
                float3 result;
                float3 light = (_LightColor * dot(-_LightDirection, normal) * 0.5 + 0.5) * _LightIntensity;
            
                float shadow = softShadow(
                position, 
                -_LightDirection,
                _ShadowDistance.x, 
                _ShadowDistance.y, 
                _ShadowPenumbra
                ) * 0.5 + 0.5;
                shadow = max(0.0, pow(shadow, _ShadowIntensity));


                result = color * light * shadow;

                return result;
                
            }

            fixed4 raymarching(float3 origin, float3 direction, float depth){
                fixed4 result = fixed4(0.01, 0.01, 0.01,1);
                if(_BackgroundEnabled){
                    result = fixed4(0.01, 0.01, 0.01,0);
                }
                const int maxSteps = _MaxIterations;
                float traveled = 0;

                
                float glowStrength = 2.0;  
                float glowWidth = 0.5; 

                int i;
                for(i = 0; i < maxSteps; i++){
                    if(traveled > _MaxDistance){ 
                        return result;
                        break;
                    }
                    

                    float3 position = origin + direction * traveled;
                    float4 distance = sdf(position);
                    if(!_ColorEnabled){
                        distance.rgb = float3(0.01, 0.01, 0.01);
                    }

                    if(distance.w < _Accuracy){ 
                        float3 normal = getNormal(position);

                        float3 s = shading(position, normal, distance.rgb);

                        if(!_ShadowEnabled){
                            s = 1;
                        }

                        result = fixed4(distance.rgb * s, 1);
                        break;
                    }

                    if(!_ColorEnabled){
                        float glow = exp(-distance.w / glowWidth) * glowStrength;
                        result.rgb += distance.rgb * glow;
                    }
                    
                    traveled += distance.w;
                }
                return result;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                float depth = LinearEyeDepth(tex2D(_CameraDepthTexture, i.uv).r);
                depth *= length(i.ray);
                fixed3 color = tex2D(_MainTex, i.uv);
                float3 rayDirection = normalize(i.ray.xyz);
                float3 rayOrigin = _WorldSpaceCameraPos;
                fixed4 result = raymarching(rayOrigin, rayDirection, depth);
                
                
                return fixed4(color * (1.0 - result.w) + result.rgb * result.w,1.0);
                // return result;
            }
            ENDCG
        }
    }
}