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
            // uniform float4 _CamWorldSpace;
            uniform float4x4 _CamFrustum, _CamToWorld;
            uniform float _MaxDistance;
            uniform float4 _Sphere;
            uniform float4 _SphereColor;
            uniform float4 _Box;
            uniform float4 _BoxColor;
            uniform float _SmoothFactor;
            uniform float _BlendFactor;
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
                float4 box = float4(_BoxColor.rgb, sDBox(position - _Box.xyz, _Box.w));

                
                return smoothMin(box, sphere, _SmoothFactor);
                // return opUS(box, sphere, _SmoothFactor);
                // return min(box.a, sphere.a);
            }

            // float4 sdf(float3 position)
            // {
            //     float4 sphere      = float4(_SphereColor.rgb, sDSphere(position - _Sphere.xyz, _Sphere.w));
            //     float4 box         = float4(_BoxColor.rgb,    sDBox(position - _Box.xyz,    _Box.w));
            //     float angle = -3.14159 * 0.5; // -90 degrees in radians
            //     float3 rotatedPos = rotateX(position - float3(0, 0, 0), angle); // center at (0,0,0)

            //     float4 torus = float4(1.0, 1.0, 0.0, sdTorus(rotatedPos, float2(2.0, 1.0)));
            //     // float4 torus       = float4(1.0, 1.0, 0.0,     sdTorus(position - float3(0, 0, 0), float2(1.0, 2.0)));
            //     float4 hex         = float4(1.0, 0.0, 1.0,     sdHexPrism(position - float3(0, 0, 0), float2(1.0, 2.0)));
            //     float4 octahedron  = float4(0.0, 1.0, 1.0,     sdOctahedron(position - float3(0, 0, 0), 2.0));

            //     float t = _BlendFactor;
                
            //     if (t < 1.0)
            //     {
            //         return morphSDF(sphere, box, t);
            //     }
            //     else if (t < 2.0)
            //     {
            //         return morphSDF(box, torus, t - 1.0);
            //     }
            //     else if (t < 3.0)
            //     {
            //         return morphSDF(torus, hex, t - 2.0);
            //     }
            //     else if (t < 4.0)
            //     {
            //         return morphSDF(hex, octahedron, t - 3.0);
            //     }
            //     else
            //     {
            //         // Clamp at last shape
            //         return octahedron;
            //     }
            // }





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
                const int maxSteps = 64;
                float traveled = 0;


                for(int i = 0; i < maxSteps; i++){
                    if(traveled > _MaxDistance){
                        result = fixed4(direction, 1);
                        break;
                    }

                    float3 position = origin + direction * traveled;
                    float4 distance = sdf(position);

                    if(distance.w < 0.01){ //We hit something
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
                fixed4 result = raymarching(rayOrigin, rayDirection);
                return result;
            }
            ENDCG
        }
    }
}