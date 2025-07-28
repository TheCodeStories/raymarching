Shader "Unlit/BlackholeVolumetric"
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
        #include "../DistanceFunctions.cginc"

        sampler2D _MainTex;
        samplerCUBE _CubeMap;
        sampler3D _Global3DNoise;
        uniform sampler2D _BlueNoiseTex;


        float4 _BoundsMin;
        float4 _BoundsMax;

        float _StepSize;
        int   _MaxIterations;
        int   _MaxShadowIterations;
        float _Accuracy;
        uniform float _NoiseStrength;
        
        uniform float4 _Sphere;
        uniform float4 _SphereColor;

        //Black Hole parameters
        uniform float _BlackHoleMass;
        uniform float3 _Cylinder;
        uniform float3 _CylinderColor;
        
        //Dust parameters
        uniform float _Density;
        uniform float _ShadowStepSize;
        uniform float _ExponentialFactor;
        uniform float _AnisotropyForward;
        uniform float _AnisotropyBackward;
        uniform float _LobeWeight;
        uniform float _CloudBrightness;
        uniform float _WhiteBoost;
        uniform float3 _LightColor;
        uniform float  _LightIntensity;
        uniform float _RotationSpeed;
        uniform float _InitialRotation;

        uniform float _Factor;
        uniform float _VerticalFadeStart;
        uniform float _VerticalFadeEnd;
        uniform float _OuterFadeStart; 
        uniform float _OuterFadeEnd;
        uniform float _InnerFadeRadius; 
        uniform float _InnerFadeWidth;

        uniform float _LightFalloff;

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

        float4 sdf(float3 position)
        {
            float4 cylinder = float4(_CylinderColor, sdUniformHollowCylinder(position - _Sphere.xyz, _Cylinder));
            return cylinder;
        }

        float HG(float g, float ct)
        {
            float d = 1 + g*g - 2*g*ct;
            return (1 - g*g)/(4*UNITY_PI*pow(d,1.5));
        }
        float doubleLobedHG(float ct, float g1, float g2, float w)
        {
            return w*HG(g1,ct) + (1-w)*HG(g2,ct);
        }

        float sampleDensity(float3 position)
        {
            float3 local = position - _Sphere.xyz;

            float2 xz = float2(local.x, local.z);
            float r = length(xz) + 0.001;
            float theta = atan2(xz.y, xz.x);

            float orbitalSpeed = _RotationSpeed / pow(r, 1.5);
            float startRotation = _InitialRotation / pow(r, 1.5);
            float angleOffset = startRotation + theta + orbitalSpeed * _Time.y;

            float2 polar = float2(
                r / _Cylinder.x,
                (local.y + _Cylinder.z * 0.5) / _Cylinder.z
            );

            // Convert polar coords back to normalized [0,1] UVW with swirl
            float u = cos(angleOffset) * polar.x * 0.5 + 0.5;
            float w = sin(angleOffset) * polar.x * 0.5 + 0.5;

            float3 diskUVW = float3(u, polar.y, w);

            // Sample noise
            float mip = 0;
            float noise = tex3D(_Global3DNoise, float4(diskUVW, mip)).r;

            float yNorm = abs(local.y) / (_Cylinder.z * 0.5);
            float verticalFade = 1.0 - smoothstep(_VerticalFadeStart, _VerticalFadeEnd, yNorm); // or use exp falloff
            
            // float r = length(float2(local.x, local.z));
            float normalizedR = r / _Cylinder.x; // 0 = center, 1 = outer edge

            // Inner fade (near black hole)
            float innerFade = smoothstep(
                _InnerFadeRadius, 
                _InnerFadeRadius + _InnerFadeWidth, 
                normalizedR
            );
            // Outer fade (toward outer edge)
            float outerFade = 1.0 - smoothstep(_OuterFadeStart, _OuterFadeEnd, normalizedR);

            // Final radial fade is a blend of both
            float radialFade = innerFade * outerFade;

            return noise * _Density * verticalFade * radialFade;
        }



        float computeTransmittance(float3 position, float3 Ld)
        {
            float tau = 0;
            int steps = _MaxShadowIterations;
            [loop]
            for (int i = 0; i < steps; i++) {
                float3 sp = position - Ld * (i * _ShadowStepSize); // Cast against light direction
                float d = sampleDensity(sp);
                tau += pow(d, _ExponentialFactor) * _ShadowStepSize;
            }
            float T = exp(-tau);
            return T;
        }
        float4 raymarching(float3 origin, float3 direction, float2 uv)
        {
            float2 bi   = rayBoxDistance(_BoundsMin.xyz, _BoundsMax.xyz, origin, direction);
            

            float2 noiseUV = frac(uv * _ScreenParams.xy / 470.0); 
            float noise = tex2Dlod(_BlueNoiseTex, float4(noiseUV, 0, 0)).r ;
            float stepOffset = (noise - 0.5) * _StepSize * _NoiseStrength;
            float traveled = bi.x;
            float  maxTraveled = bi.x + bi.y;

            const float stepSize = _StepSize;

            float3 position = origin + direction * traveled;
            
            float glow = 0.0;

            float3 baseCol = float3(0.0, 0.0, 0.0);
            float3 cloudCol = float3(0.0, 0.0, 0.0);
            float  transmittance  = 1;
            
            [loop]
            for (int i = 0; i < _MaxIterations ; i++) {
                float4 distance = sdf(position + (direction * stepOffset));
                float bdist = length(position);

                if(bdist < _Sphere.w && distance.w > maxTraveled) break;
                
                if(distance.w < _Accuracy){
                    float density = sampleDensity(position + (direction * stepOffset));

                    if(density > 0.01){
                        float3 Ld = normalize(_Sphere.xyz - position);
                        float  Tsh = computeTransmittance(position, Ld);

                        float3 Vd = -direction;
                        float  cosT = dot(Ld, Vd);
                        float  phase = doubleLobedHG(cosT, _AnisotropyForward, _AnisotropyBackward, _LobeWeight);
                    
                        float softenedDensity = pow(density, _CloudBrightness);
                        float scat = softenedDensity * _StepSize;

                        float  r    = length(position - _Sphere.xyz);


                        float  dist2 = dot(_Sphere.xyz - position, _Sphere.xyz - position);
                        float  atten = _LightIntensity / (max(dist2, 0.001) * 0.06);

                        // float d = max(r - (_Cylinder.x - 10), 0.01); // start falloff *outside* disk radius
                        // float atten = _LightIntensity / pow(d, _LightFalloff) * 0.1;


                        float  tRad = saturate((r - _Cylinder.x) / (_Cylinder.y - _Cylinder));
                        float3 hotColor  = float3(2.0, 2.0, 2.0);
                        float3 sampleColor = hotColor * (1-tRad) + (float3(3, 6, 12) * 2);
                        
                        
                        // float3 sampleColor = hotColor * (1-tRad) + (float3(10, 5, 3) * 2);
                        // float3 hotColor = float3(3.0, 3.0, 3.0); // white-hot center
                        // float3 coolerColor = float3(1.0, 2.0, 4.0); // cooler blue
                        // float3 sampleColor = lerp(hotColor, coolerColor, tRad); // temperature gradient
                        // sampleColor *= atten; // apply falloff
                        
                        float saturation = pow(1.0 - tRad, _LightFalloff);
                        sampleColor *= saturation;

                        cloudCol.rgb += transmittance
                                    * Tsh
                                    * atten
                                    * sampleColor
                                    * phase
                                    * scat
                                    * _CylinderColor
                                    * density;
                        transmittance *= exp(-pow(density, _ExponentialFactor) * _StepSize);
                        if (transmittance < 0.01) break;
                    }
                }

                direction = normalize(direction - (position * _StepSize / pow(bdist, 3) * _BlackHoleMass));
                position += direction * stepSize;
            }
            if (length(position) < _Sphere.w)
                baseCol = _SphereColor * transmittance;
            
            // else
            //     baseCol =  texCUBE(_CubeMap, direction).rgb * transmittance * 0.1;

            return float4(baseCol + cloudCol, 1.0);
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