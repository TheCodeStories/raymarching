using System;
using System.Collections;
using System.Collections.Generic;
using Unity.VisualScripting;
using UnityEngine;
using UnityEngine.Experimental.GlobalIllumination;

[ExecuteInEditMode, ImageEffectAllowedInSceneView]
public class BlackholeVolume : MonoBehaviour
{
    public Transform container;
    Material material;

    [Header("Raymarching Variables")]
    [Range(0.001f, 0.1f)]
    public float _stepSize;

    public int   _maxIterations;
    [Range(0.001f, 0.1f)]
    public float _accuracy;

    [Header("Objects")]
    public Vector4 _sphere;
    public Color _sphereColor;
    public Vector3 _cylinder;
    public Color _cylinderColor;


    [Header("Black Hole")]
    public float _blackHoleMass;
    public Cubemap _skyboxCubemap;
    public float _rotationSpeed;


    [Header("Glow")]
    public Color _mainGlowColor;
    public float _mainGlowWidth;
    public float _mainGlowSharpness;
    public float _falloff;
    [Range(0.0f,1.0f)]
    public float _glowIntensity;
    public float _glowLimit;


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
            material.SetFloat("_Accuracy", _accuracy);

            material.SetVector("_Sphere", _sphere);
            material.SetColor("_SphereColor", _sphereColor);
            material.SetVector("_Cylinder", _cylinder);
            material.SetColor("_CylinderColor", _cylinderColor);
            material.SetFloat("_BlackHoleMass", _blackHoleMass);
            material.SetTexture("_CubeMap", _skyboxCubemap);

            material.SetColor("_MainGlowColor", _mainGlowColor);
            material.SetFloat("_MainGlowWidth", _mainGlowWidth);
            material.SetFloat("_MainGlowSharpness", _mainGlowSharpness);
            material.SetFloat("_GlowIntensity", _glowIntensity);
            material.SetFloat("_Falloff", _falloff);
            material.SetFloat("_GlowLimit", _glowLimit);
            material.SetFloat("_RotationSpeed", _rotationSpeed);
        }
    }
}