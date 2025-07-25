using System.Collections;
using System.Collections.Generic;
using Unity.VisualScripting;
using UnityEngine;
using UnityEngine.Experimental.GlobalIllumination;

[ExecuteInEditMode, ImageEffectAllowedInSceneView]
public class CloudVolume : MonoBehaviour
{
    public Shader shader;
    public Transform container;
    Material material;

    [Header("Raymarching Variables")]
    [Range(0.1f, 100.0f)]
    public float _stepSize;

    [Range(1.0f, 10.0f)]
    public float _shadowStepSize;
    public int   _maxIterations;
    public float _accuracy;
    [Range(0.0f, 1.0f)]
    public float _exponentialFactor;
    public Texture2D _blueNoiseTexture;


    [Header("Light")]
    public Light _light;

    [Header("Cloud")]
    public float _density;
    [Range(-1.0f, 1.0f)]
    public float _anisotropyForward;
    [Range(-1.0f, 1.0f)]
    public float _anisotropyBackward;
    [Range(-1.0f, 1.0f)]
    public float _lobeWeight;
    public float _cloudBrightness;
    public float _whiteBoost;

    void Update() {
        Camera.main.depthTextureMode |= DepthTextureMode.Depth;

        var renderer = GetComponent<MeshRenderer>();
        if (renderer != null)
        {
            var material = renderer.sharedMaterial;
            material.SetTexture("_BlueNoiseTex", _blueNoiseTexture);
            material.SetVector("_BoundsMin", container.position - container.localScale / 2);
            material.SetVector("_BoundsMax", container.position + container.localScale / 2);
            material.SetFloat("_StepSize", _stepSize);
            material.SetFloat("_ShadowStepSize", _shadowStepSize);
            material.SetInt("_MaxIterations", _maxIterations);
            material.SetFloat("_Accuracy", _accuracy);
            material.SetFloat("_ExponentialFactor", _exponentialFactor);

            // material.SetVector("_LightPosition", _light.transform.position);
            material.SetVector("_LightDirection", -_light.transform.forward);
            material.SetColor("_LightColor", _light.color);
            material.SetFloat("_LightIntensity", _light.intensity);

            material.SetFloat("_Density", _density);
            material.SetFloat("_AnisotropyForward",_anisotropyForward);
            material.SetFloat("_AnisotropyBackward", _anisotropyBackward);
            material.SetFloat("_LobeWeight", _lobeWeight);
            material.SetFloat("_CloudBrightness", _cloudBrightness);
            material.SetFloat("_WhiteBoost", _whiteBoost);
        }
    }
}