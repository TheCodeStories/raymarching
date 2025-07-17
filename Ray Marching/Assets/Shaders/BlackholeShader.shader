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
            #include "DistanceFunctions.cginc"

            sampler2D _MainTex;
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
            uniform float3 _Torus;
            uniform float3 _TorusColor;


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
                float4 sphere = float4(_SphereColor.rgb, sdSphere(position - _Sphere.xyz, _Sphere.w));
                float4 torus = float4(_TorusColor, sdTorusFlattened(position, _Torus) );

                // return torus;
                return smoothMin(sphere, torus, 0.0);
                // return sphere;
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
                const int maxSteps = _MaxIterations;
                const float stepSize = _StepSize;
                float traveled = 0;
                float3 startDirection = direction;

                for (int i = 0; i < maxSteps; i++) {
                    float3 position = origin + direction * traveled;
                    float3 toBH = _Sphere.xyz - position;
                    float distanceToCenter = length(toBH);
                    float gravityStrength = _BlackHoleMass / (distanceToCenter * distanceToCenter + 0.01);

                    float3 gravityDir = normalize(toBH);

                    float gravitationalLensing = gravityStrength * stepSize;

                    direction = normalize(lerp(direction, gravityDir, gravitationalLensing));

                    float4 distance = sdf(position);
                    if (distance.w < _Accuracy) {
                        return fixed4(distance.rgb, 1.0); // Hit something
                    }

                    traveled += stepSize;
                    if (traveled > _MaxDistance) {
                        break;
                    }
                }

                // After ray is bent, sample skybox with final direction
                return fixed4(texCUBE(_CubeMap, direction).rgb, 0.0);
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