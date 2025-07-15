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

            sampler2D _MainTex;
            // uniform float4 _CamWorldSpace;
            uniform float4x4 _CamFrustum, _CamToWorld;
            uniform float _MaxDistance;
            uniform float4 _Sphere;
            uniform float3 _LightDirection;

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

            float SDSphere(float3 position, float radius)
            {
                return length(position) - radius;
            }

            float SDF(float3 position)
            {
                float sphere = SDSphere(position - _Sphere.xyz, _Sphere.w);

                return sphere;
            }

            float3 getNormal(float3 position){
                const float2 offset = float2(0.001, 0.0);
                float3 n = float3(
                    SDF(position + offset.xyy) - SDF(position - offset.xyy),
                    SDF(position + offset.yxy) - SDF(position - offset.yxy),
                    SDF(position + offset.yyx) - SDF(position - offset.yyx)
                );
                return normalize(n);
            }

            fixed4 raymarching(float3 origin, float3 direction){
                fixed4 result = fixed4(1,1,1,1);
                const int maxSteps = 128;
                float traveled = 0;


                for(int i = 0; i < maxSteps; i++){
                    if(traveled > _MaxDistance){
                        result = fixed4(direction, 1);
                        break;
                    }

                    float3 position = origin + direction * traveled;
                    float distance = SDF(position);

                    if(distance < 0.01){ //We hit something
                        float3 normal = getNormal(position);

                        float light = dot(-_LightDirection, normal);

                        result = fixed4(light, light, light, 1);
                    }

                    traveled += distance;
                }
                
                return result;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                float3 rayDirection = normalize(i.ray.xyz);
                float3 rayOrigin = _WorldSpaceCameraPos;
                fixed4 result = raymarching(rayOrigin, rayDirection);
                return result;
            }
            ENDCG
        }
    }
}