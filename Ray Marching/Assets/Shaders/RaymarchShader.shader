Shader "Hidden/RaymarchShader"
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
            uniform float4 _Box;
            uniform float4 _BoxColor;
            uniform float _Ground;
            uniform float3 _GroundColor;
            uniform float _SmoothFactor;
            uniform float _BlendFactor;
            uniform float3 _LightDirection;
            uniform float3 _LightColor;
            uniform float _LightIntensity;
            uniform float _ShadowIntensity;
            uniform float _ShadowPenumbra;
            uniform float2 _ShadowDistance;
            uniform int _MaxIterations;
            uniform float _Accuracy;
            uniform float _AoStepSize;
            uniform int _AoIterations;
            uniform float _AoIntensity;

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

            
            float sDBox(float3 position, float b)
            {
                float3 q = abs(position) - b;
                return length(max(q,0.0)) + min(max(q.x,max(q.y,q.z)),0.0);
            }
            
            float4 opUS(float4 d1, float4 d2, float k){
                float h = clamp(0.5 + 0.5 + (d2.w - d1.w) / k, 0.0, 1.0);
                float3 color = lerp(d2.rgb, d1.rgb, h);
                float distance = lerp(d2.w, d1.w, h) - k * h * (1.0 - h);
                return float4(color, distance);
            }

            float4 smoothMin(float4 a, float4 b, float smoothFactor)
            {
                if (smoothFactor < 0.1)
                {
                    return (a.a < b.a) ? a : b;
                }

                float da = a.a;
                float db = b.a;

                float wa = exp2(-da / smoothFactor);
                float wb = exp2(-db / smoothFactor);
                float wSum = wa + wb;

                float d = -smoothFactor * log2(wSum);
                float3 color = (a.rgb * wa + b.rgb * wb) / wSum;

                return float4(color, d);
            }

            float4 sdf(float3 position)
            {
                float4 sphere = float4(_SphereColor.rgb, sDSphere(position - _Sphere.xyz, _Sphere.w));

                return sphere;
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
                    float h = sdf(ro + rd * traveled).w; // FIXED: Get distance
                    if(h < 0.001){
                        return 0.0;
                    }
                    result = min(result, k * h/traveled);
                    traveled += h; // Also missing!
                }
                return clamp(result, 0.0, 1.0);
            }

            float ambientOclusion(float3 position, float3 normal)
            {
                float ao = 0.0;
                float3 origin = position + normal * 0.01;

                for (int i = 1; i <= _AoIterations; i++)
                {
                    float distance = _AoStepSize * i;
                    float distToScene = sdf(origin + normal * distance).w;
                    ao += max(0.0, distance - distToScene) / distance;
                }

                ao /= _AoIterations;
                return pow(saturate(1.0 - ao), 1.5) * _AoIntensity;
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

                float ao = ambientOclusion(position, normal);

                result = color * light * shadow;

                return result;
                
            }

            fixed4 raymarching(float3 origin, float3 direction, float depth){
                fixed4 result = fixed4(0.0,0.0,0.0,1);
                const int maxSteps = _MaxIterations;
                float traveled = 0;

                int i;
                for(i = 0; i < maxSteps; i++){
                    if(traveled > _MaxDistance || traveled >= depth){ 
                        return fixed4(direction, 0);
                        break;
                    }
                    

                    float3 position = origin + direction * traveled;
                    float4 distance = sdf(position);

                    if(distance.w < _Accuracy){ //We hit something
                        float3 normal = getNormal(position);

                        float3 s = shading(position, normal, distance.rgb);

                        result = fixed4(distance.rgb * s, 1);
                        break;
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
            }
            ENDCG
        }
    }
}