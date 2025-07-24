Shader "Unlit/BoundedCloudShader"
{
    Properties
    {
        _MainTex            ("Background (RGB)",    2D)    = "white" {}
        _Global3DNoise      ("Noise",               3D)    = "white" {}
        _BlueNoiseTex("Blue Noise Texture", 2D) = "white" {}



        _Density            ("Density",             Float) = 1.0
        _StepSize           ("Step Size",           Float) = 0.1
        _ShadowStepSize     ("Shadow Step Size",    Float) = 0.5
        _MaxIterations      ("Max Ray Steps",       Int)   = 128
        _Accuracy           ("Hit Accuracy",        Float) = 0.001
        _ExponentialFactor  ("Density Exponent",    Float) = 1.0

        _LightDirection     ("Light Direction",     Vector) = (0,-1,0,0)
        _LightColor         ("Light Color",         Color)  = (1,1,1,1)
        _LightIntensity     ("Light Intensity",     Float)  = 1.0

        _AnisotropyForward  ("HG Forward G",        Float) = 0.6
        _AnisotropyBackward ("HG Backward G",       Float) = -0.3
        _LobeWeight         ("HG Lobe Weight",      Float) = 0.75


    }
    SubShader
    {
        Tags { "Queue"="Transparent" "RenderType"="Transparent" }
        Cull Off
        ZWrite Off
        ZTest LEqual
        Blend SrcAlpha OneMinusSrcAlpha

        Pass
        {
        CGPROGRAM
        #pragma vertex vert
        #pragma fragment frag
        #pragma target 3.0

        #include "UnityCG.cginc"
        #include "../DistanceFunctions.cginc"

        sampler2D _MainTex;
        sampler2D _CameraDepthTexture;

        sampler3D _Global3DNoise;
        uniform sampler2D _BlueNoiseTex;

        float _Density;
        float _StepSize;
        float _ShadowStepSize;
        int   _MaxIterations;
        float _Accuracy;
        float _ExponentialFactor;

        float3 _LightDirection;
        float3 _LightColor;
        float  _LightIntensity;

        float _AnisotropyForward;
        float _AnisotropyBackward;
        float _LobeWeight;

        float4 _BoundsMin;
        float4 _BoundsMax;

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

        // --- box intersection ---
        float2 rayBoxDistance(float3 bmin, float3 bmax, float3 ro, float3 rd)
        {
            float3 inv = 1.0/rd;
            float3 t0  = (bmin - ro)*inv;
            float3 t1  = (bmax - ro)*inv;
            float3 tmin= min(t0,t1);
            float3 tmax= max(t0,t1);

            float entry = max(max(tmin.x,tmin.y), tmin.z);
            float exit  = min(min(tmax.x,tmax.y), tmax.z);

            bool inside = all(ro > bmin) && all(ro < bmax);
            if (inside) entry = 0;
            float distIn = max(0, exit-entry);
            return float2(max(0,entry), distIn);
        }

        // --- phase functions ---
        float HG(float g, float ct)
        {
            float d = 1 + g*g - 2*g*ct;
            return (1 - g*g)/(4*UNITY_PI*pow(d,1.5));
        }
        float doubleLobedHG(float ct, float g1, float g2, float w)
        {
            return w*HG(g1,ct) + (1-w)*HG(g2,ct);
        }

        float sampleDensity(float3 p)
        {
            float3 uvw = (p - _BoundsMin.xyz) 
                    / (_BoundsMax.xyz - _BoundsMin.xyz);

            float noise = tex3Dlod(_Global3DNoise, float4(uvw, 0)).r;
            // float noise = tex3D(_Global3DNoise, uvw).r;

            return _Density * noise;
        }

        float computeTransmittance(float3 position, float3 Ld)
        {
            float tau = 0;
            int steps = 8;
            for (int i = 0; i < steps; i++) {
                float3 sp = position - Ld * (i * _ShadowStepSize); // Cast against light direction
                float d = sampleDensity(sp);
                tau += pow(d, _ExponentialFactor) * _ShadowStepSize;
            }
            float T = exp(-tau);
            return T;
        }

        // your SDF: sphere + box smooth‐min
        float4 sdf(float3 position)
        {
            float4 sphere = float4(1,0,0, sdSphere(position - (_BoundsMin.xyz+_BoundsMax.xyz)*0.5, 0.5));
            // float4 box = float4(1,1,1, sdBox(position - (_BoundsMin.xyz+_BoundsMax.xyz)*0.5, float3(0.5,0.5,0.5)));
            return sphere;
        }
        // the raymarcher
        fixed4 raymarching(float3 ro, float3 rd, out float hitT, float2 uv)
        {

            float2 bi   = rayBoxDistance(_BoundsMin.xyz, _BoundsMax.xyz, ro, rd);
            
            if (bi.y <= 0) {
                hitT = -1.0;
                return fixed4(0,0,0,0);
            }
            // float2 noiseUV = frac(uv / 128.0); // 128 = blue noise texture size
            float2 noiseUV = frac(uv * _ScreenParams.xy / 128.0); // Tile blue noise every 128px
            float noise = tex2D(_BlueNoiseTex, noiseUV).r;
            float traveled = bi.x + (noise - 0.5) * 2.0 * _StepSize;


            // float  traveled = bi.x;
            float  maxTraveled = bi.x + bi.y;

            float3 col = 0;
            float  transmittance  = 1;
            bool   hitCloud = false;
            float  cloudEntryT = -1.0;

            // [loop]
            for(int i = 0; i < _MaxIterations && traveled < maxTraveled; i++)
            {
                float3 position = ro + rd * traveled;

                float density = sampleDensity(position);

                if (density > 0.01)
                {
                    if (!hitCloud)
                    {
                        hitCloud = true;
                        cloudEntryT = traveled;
                    }

                    float3 Ld  = normalize(-_LightDirection);
                    float  Tsh = computeTransmittance(position, Ld);

                    float3 Vd = -rd;
                    float  cosT = dot(Ld, Vd);
                    float  phase = doubleLobedHG(cosT, _AnisotropyForward, _AnisotropyBackward, _LobeWeight);

                    float scat = density * _StepSize;
                    col += transmittance * Tsh * _LightColor * _LightIntensity * phase * scat;

                    transmittance *= exp(-pow(density, _ExponentialFactor) * _StepSize);
                    if (transmittance < 0.01) break;
                }

                traveled += _StepSize;
            }

            hitT = hitCloud ? cloudEntryT : -1.0;
            return fixed4(col, 1.0 - transmittance);
        }

        fixed4 frag(v2f i) : SV_Target
        {
            fixed3 bg = tex2D(_MainTex, i.uv).rgb;

            float sceneD = Linear01Depth(tex2D(_CameraDepthTexture, i.uv).r);

            float3 rd = normalize(i.viewVector);
            float3 ro  = _WorldSpaceCameraPos;

            float hitT;
            fixed4 vm = raymarching(ro, rd, hitT, i.uv);

            if (vm.a > 0 && hitT > 0.0)
            {
                float3 hitPos = ro + rd * hitT;
                float4 cp     = UnityWorldToClipPos(hitPos);
                float rayD    = Linear01Depth(cp.z / cp.w);

                if (rayD > sceneD)
                    discard;
            }

            return fixed4(lerp(bg, vm.rgb, vm.a), vm.a);
        }
        ENDCG
        }
    }
    FallBack Off
}