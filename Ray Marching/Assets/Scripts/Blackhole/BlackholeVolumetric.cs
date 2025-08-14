using System;
using System.Collections;
using System.Collections.Generic;
using Unity.VisualScripting;
using UnityEngine;
using UnityEngine.Experimental.GlobalIllumination;

[ExecuteInEditMode, ImageEffectAllowedInSceneView]
public class BlackholeVolumetric : MonoBehaviour
{
    public Transform container;
    Material material;

    [Header("Raymarching Variables")]
    [Range(0.001f, 10.0f)]
    public float _stepSize;

    public int   _maxIterations;
    [Range(0.0f, 10.0f)] public float _shadowStepSize;
    public int   _maxShadowIterations;

    [Range(0.001f, 100f)] public float _accuracy;
    public Texture2D _blueNoiseTexture;
    public float _noiseStrength;

    [Header("Objects")]
    public Vector4 _sphere;
    public Color _sphereColor;
    public Vector3 _cylinder;
    public Color _cylinderColor;


    [Header("Black Hole")]
    public float _blackHoleMass;
    public Cubemap _skyboxCubemap;

    [Header("Accretion Disk")]
    public float _density;
    [Range(0.0f, 1.0f)] public float _exponentialFactor;
    [Range(-1.0f, 1.0f)] public float _anisotropyForward;
    [Range(-1.0f, 1.0f)] public float _anisotropyBackward;
    [Range(-1.0f, 1.0f)] public float _lobeWeight;
    public float _cloudBrightness;
    public float _whiteBoost;
    public float _lightIntensity;
    public float _rotationSpeed;
    public float _baseRotationSpeed;
    public float _initialRotation;
    public float _verticalFadeStart;
    public float _verticalFadeEnd;
    public float _outerFadeStart;
    public float _outerFadeEnd;
    public float _innerFadeRadius;
    public float _innerFadeWidth;
    public float _lightFalloff;
    public float _dopplerStrength;
    
    void Update() {
        Camera.main.depthTextureMode |= DepthTextureMode.Depth;

        var renderer = GetComponent<MeshRenderer>();
        if (renderer != null)
        {
            material = renderer.sharedMaterial;
            material.SetVector("_BoundsMin", container.position - container.localScale / 2);
            material.SetVector("_BoundsMax", container.position + container.localScale / 2);
            material.SetFloat("_StepSize", _stepSize);
            material.SetInt("_MaxIterations", _maxIterations);
            material.SetInt("_MaxShadowIterations", _maxShadowIterations);
            material.SetFloat("_Accuracy", _accuracy);
            material.SetTexture("_BlueNoiseTex", _blueNoiseTexture);
            material.SetFloat("_NoiseStrength", _noiseStrength);

            material.SetVector("_Sphere", _sphere);
            material.SetColor("_SphereColor", _sphereColor);
            material.SetVector("_Cylinder", _cylinder);
            material.SetColor("_CylinderColor", _cylinderColor);
            material.SetFloat("_BlackHoleMass", _blackHoleMass);
            material.SetTexture("_CubeMap", _skyboxCubemap);

            material.SetFloat("_RotationSpeed", _rotationSpeed);
            material.SetFloat("_BaseRotationSpeed", _baseRotationSpeed);
            material.SetFloat("_InitialRotation", _initialRotation);
            material.SetFloat("_Density", _density);
            material.SetFloat("_ShadowStepSize", _shadowStepSize);
            material.SetFloat("_ExponentialFactor", _exponentialFactor);
            material.SetFloat("_AnisotropyForward", _anisotropyForward);
            material.SetFloat("_AnisotropyBackward", _anisotropyBackward);
            material.SetFloat("_LobeWeight", _lobeWeight);
            material.SetFloat("_CloudBrightness", _cloudBrightness);
            material.SetFloat("_WhiteBoost", _whiteBoost);

            material.SetFloat("_LightIntensity", _lightIntensity);


            material.SetFloat("_VerticalFadeStart", _verticalFadeStart);
            material.SetFloat("_VerticalFadeEnd", _verticalFadeEnd);
            material.SetFloat("_OuterFadeStart", _outerFadeStart);
            material.SetFloat("_OuterFadeEnd", _outerFadeEnd);
            material.SetFloat("_InnerFadeRadius", _innerFadeRadius);
            material.SetFloat("_InnerFadeWidth", _innerFadeWidth);

            material.SetFloat("_LightFalloff", _lightFalloff);
            material.SetFloat("_DopplerStrength", _dopplerStrength);
        }
    }
}