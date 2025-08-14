using System;
using System.Collections;
using System.Collections.Generic;
using Unity.VisualScripting;
using UnityEngine;
using UnityEngine.Experimental.GlobalIllumination;

[ExecuteInEditMode, ImageEffectAllowedInSceneView]
public class SimpleBlackholeVolumetric : MonoBehaviour
{
    public Transform container;
    Material material;

    [Header("Raymarching Variables")]
    [Range(0.001f, 10.0f)]
    public float _stepSize;

    public int   _maxIterations;

    [Range(0.001f, 10f)]
    public float _accuracy;

    [Header("Objects")]
    public Vector4 _sphere;
    public Color _sphereColor;

    [Header("Black Hole")]
    public float _blackHoleMass;
    public Cubemap _skyboxCubemap;

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

            material.SetFloat("_BlackHoleMass", _blackHoleMass);
            
            material.SetTexture("_CubeMap", _skyboxCubemap);
        }
    }
}