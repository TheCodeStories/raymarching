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
        #include "../Utils.cginc"

        sampler2D _MainTex;
        samplerCUBE _CubeMap;
        sampler3D _Global3DNoise;
        uniform sampler2D _BlueNoiseTex;


        float4 _BoundsMin;
        float4 _BoundsMax;

        float _StepSize;
        int   _MaxIterations;
        uniform float _ShadowStepSize;
        int   _MaxShadowIterations;
        float _Accuracy;
        uniform float _NoiseStrength;
        
        uniform float4 _Sphere;
        uniform float4 _SphereColor;

        uniform float _BlackHoleMass;
        uniform float3 _Cylinder;
        uniform float3 _CylinderColor;
        
        uniform float _Density;
        uniform float _ExponentialFactor;
        uniform float _AnisotropyForward;
        uniform float _AnisotropyBackward;
        uniform float _LobeWeight;
        uniform float _CloudBrightness;
        uniform float  _LightIntensity;
        uniform float _RotationSpeed;
        uniform float _BaseRotationSpeed;
        uniform float _InitialRotation;
        uniform float _VerticalFadeStart;
        uniform float _VerticalFadeEnd;
        uniform float _OuterFadeStart; 
        uniform float _OuterFadeEnd;
        uniform float _InnerFadeRadius; 
        uniform float _InnerFadeWidth;
        uniform float _LightFalloff;
        uniform float _DopplerStrength;


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

        //Signed distance field
        float4 sdf(float3 position)
        {
            float4 cylinder = float4(_CylinderColor, sdUniformHollowCylinder(position - _Sphere.xyz, _Cylinder));
            return cylinder;
        }

        //Disk density sampling
        float sampleDensity(float3 position)
        {
            float3 local = position - _Sphere.xyz;

            float2 xz = float2(local.x, local.z);
            float r = length(xz) + 0.001;
            float theta = atan2(xz.y, xz.x);

            float orbitalSpeed = _RotationSpeed / pow(r, 1.5) + _BaseRotationSpeed;
            float startRotation = _InitialRotation / pow(r, 1.5);
            float angleOffset = startRotation + theta + orbitalSpeed * _Time.y;

            float2 polar = float2(
                r / _Cylinder.x,
                (local.y + _Cylinder.z * 0.5) / _Cylinder.z
            );

            float u = cos(angleOffset) * polar.x * 0.5 + 0.5;
            float w = sin(angleOffset) * polar.x * 0.5 + 0.5;
            float3 diskUVW = float3(u, polar.y, w);

            float noise = tex3D(_Global3DNoise, float4(diskUVW, 0)).r;

            float radiusNorm = r / _Cylinder.x;
            float thicknessAtR = _Cylinder.z * (1.0 + sqrt(radiusNorm) * 0.5);

            float yNorm = abs(local.y) / thicknessAtR;
            float verticalFade = 1.0 - smoothstep(_VerticalFadeStart, _VerticalFadeEnd, yNorm);



            float innerFade = smoothstep(
                _InnerFadeRadius, 
                _InnerFadeRadius + _InnerFadeWidth, 
                radiusNorm
            );

            float outerFade = 1.0 - smoothstep(_OuterFadeStart, _OuterFadeEnd, radiusNorm);
            float radialFade = innerFade * outerFade;

            float mainDensity = noise * _Density * verticalFade * radialFade;

            return mainDensity;
        }

        float computeTransmittance(float3 position, float3 Ld)
        {
            float tau = 0;
            int steps = _MaxShadowIterations;
            [loop]
            for (int i = 0; i < steps; i++) {
                float3 sp = position - Ld * (i * _ShadowStepSize);
                float d = sampleDensity(sp);
                tau += pow(d, _ExponentialFactor) * _ShadowStepSize;
            }
            float T = exp(-tau);
            return T;
        }

        //Main function
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
                float bdist = length(position - _Sphere.xyz);

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
                        float  atten = _LightIntensity  / (max(dist2, 0.001) * 0.06);

                        float  tRad = saturate((r - _Cylinder.x) / (_Cylinder.y - _Cylinder));
                        float3 hotColor  = float3(2.0, 2.0, 2.0);
                        float3 sampleColor = hotColor * (1-tRad) + (float3(3, 6, 12) * 2); // Blue
                        

                        float saturation = pow(1.0 - tRad, _LightFalloff);
                        sampleColor *= saturation;

                        float3 local = position - _Sphere.xyz;

                        float3 toCam = normalize(_WorldSpaceCameraPos - position);

                        float3 tangentDir = normalize(float3(-local.z, 0, local.x)); 

                        float v = _RotationSpeed / pow(r, 1.5); 

                        float3 vel = tangentDir * v;

                        float relVel = -dot(normalize(vel), toCam);

                        float dopplerBoost = 1.0 + _DopplerStrength * relVel; 
                        dopplerBoost = max(dopplerBoost, 0.0);

                        sampleColor *= dopplerBoost;

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

                float3 toBH   = position - _Sphere.xyz;
                float   dist  = length(toBH);
                float3 gravity = toBH * (_StepSize / pow(dist, 3) * _BlackHoleMass);

                direction = normalize(direction - gravity);
                position += direction * stepSize;
            }
            if (length(position) < _Sphere.w)
                baseCol = _SphereColor * transmittance;
            
            else
                baseCol =  texCUBE(_CubeMap, direction).rgb * transmittance * 0.1;

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