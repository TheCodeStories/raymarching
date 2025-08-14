Shader "Unlit/SimpleBlackholeVolumetric"
{
    Properties
    {
        _MainTex            ("Background (RGB)",    2D)    = "white" {}
        _StepSize           ("Step Size",           Float) = 0.1
        _MaxIterations      ("Max Ray Steps",       Int)   = 128
        _Accuracy           ("Hit Accuracy",        Float) = 0.001

    }
    SubShader
    {
        Tags { "Queue"="Transparent" "RenderType"="Transparent" }
        Cull Off
        ZWrite Off
        ZTest LEqual
        Blend One OneMinusSrcAlpha

        Pass
        {
        CGPROGRAM
        #pragma vertex vert
        #pragma fragment frag
        #pragma target 3.0

        #include "UnityCG.cginc"
        #include "../Utils.cginc"

        sampler2D _MainTex;
        samplerCUBE _CubeMap;
        sampler3D _Global3DNoise;
        uniform sampler2D _BlueNoiseTex;


        float4 _BoundsMin;
        float4 _BoundsMax;

        float _StepSize;
        int   _MaxIterations;
        float _Accuracy;

        uniform float4 _Sphere;
        uniform float4 _SphereColor;

        uniform float _BlackHoleMass;



        struct appdata {
            float4 vertex : POSITION;
        };

        struct v2f {
            float4 pos        : SV_POSITION;
            float3 worldPos   : TEXCOORD0;
            float3 viewVector : TEXCOORD1;
            float2 uv         : TEXCOORD2;
        };

        v2f vert(appdata v)
        {
            v2f o;
            float4 worldPos4 = mul(unity_ObjectToWorld, v.vertex);
            o.worldPos   = worldPos4.xyz;
            o.pos        = UnityObjectToClipPos(v.vertex);
            o.viewVector = o.worldPos - _WorldSpaceCameraPos;
            o.uv         = ComputeGrabScreenPos(o.pos).xy * _ScreenParams.xy; 
            return o;
        }

        float4 sdf(float3 position)
        {
            float4 sphere = float4(_SphereColor.rgb, sdSphere(position - _Sphere.xyz, _Sphere.w));
            return sphere;
        }

        float4 raymarching(float3 origin, float3 direction, float2 uv)
        {
            float2 bi   = rayBoxDistance(_BoundsMin.xyz, _BoundsMax.xyz, origin, direction);
            
            float traveled = bi.x;
            float  maxTraveled = bi.x + bi.y;

            const float stepSize = _StepSize;

            float3 result;

            float3 position = origin + direction * traveled;
            
            for (int i = 0; i < _MaxIterations ; i++) {
                float4 distance = sdf(position + (direction * _StepSize));
                float bdist = length(position);

                if(bdist < _Sphere.w && distance.w > maxTraveled) break;
            
                direction = normalize(direction - (position * _StepSize / pow(bdist, 3) * _BlackHoleMass));
                position += direction * stepSize;
            }
            if (length(position) < _Sphere.w)
                result = _SphereColor;
            
            else
                result =  texCUBE(_CubeMap, direction).rgb * 0.5;

            return float4(result, 1.0);
        }
        fixed4 frag(v2f i) : SV_Target
        {
            fixed3 bg = tex2D(_MainTex, i.uv).rgb;

            float3 rd = normalize(i.viewVector);
            float3 ro  = _WorldSpaceCameraPos;

            float4 vm = raymarching(ro, rd, i.uv);

            return float4(vm.rgb, 1.0);
        }
        ENDCG
        }
    }
    FallBack Off
}