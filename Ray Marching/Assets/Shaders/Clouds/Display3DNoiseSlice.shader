Shader "Hidden/Display3DNoiseSlice"
{
    Properties { _VolumeTex("VolumeTex", 3D) = "" }
    SubShader
    {
        Pass
        {
            ZTest Always Cull Off ZWrite Off
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"

            sampler3D _VolumeTex;
            float _Slice;

            struct appdata { float4 vertex : POSITION; float2 uv : TEXCOORD0; };
            struct v2f { float2 uv : TEXCOORD0; float4 vertex : SV_POSITION; };

            v2f vert(appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                return o;
            }

            fixed4 frag(v2f i) : SV_Target
            {
                return tex3D(_VolumeTex, float3(i.uv, _Slice));
            }
            ENDCG
        }
    }
}
