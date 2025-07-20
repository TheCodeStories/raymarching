using System.Collections;
using System.Collections.Generic;
using Unity.VisualScripting;
using UnityEngine;
using UnityEngine.Experimental.GlobalIllumination;

[RequireComponent(typeof(Camera))]
[ExecuteInEditMode]
public class CloudCamera : MonoBehaviour
{
    [SerializeField]
    private Shader _shader;

    public Material _raymarchMaterial
    {
        get
        {
            if (!_raymarchMat && _shader)
            {
                _raymarchMat = new Material(_shader);
                _raymarchMat.hideFlags = HideFlags.HideAndDontSave;
            }
            return _raymarchMat;
        }
    }
    private Material _raymarchMat;

    public Camera _camera
    {
        get
        {
            if (!_cam)
            {
                _cam = GetComponent<Camera>();
            }
            return _cam;
        }
    }

    [Header("Components")]
    private Camera _cam;

    [Header("Raymarching Variables")]
    public float _maxDistance;
    public int _maxIterations;
    [Range(0.001f, 0.1f)]
    public float _accuracy;
    public float _smoothFactor;
    public float _blendFactor;

    [Header("Objects")]
    public Vector4 _sphere;
    public Color _sphereColor;

    [Header("Cloud")]
    public float _density;

    [Header("Lighting")]
    public Light _light;

    [Range(0.001f, 1.0f)]
    public float _stepSize;

    [Range(0.0f, 1.0f)]
    public float _shadowStepSize;
    [Range(-1.0f, 1.0f)]
    public float _anisotropyForward;   // e.g. 0.6
    [Range(-1.0f, 1.0f)]
    public float _anisotropyBackward;  // e.g. -0.3
    [Range(-1.0f, 1.0f)]
    public float _lobeWeight;          // e.g. 0.75
    [Range(-1.0f, 1.0f)]
    public float _exponentialFactor;
    private void OnRenderImage(RenderTexture source, RenderTexture destination)
    {
        if (!_raymarchMaterial)
        {
            Graphics.Blit(source, destination);
            return;
        }

        _raymarchMaterial.SetMatrix("_CamFrustum", CamFrustum(_camera));
        _raymarchMaterial.SetMatrix("_CamToWorld", _camera.cameraToWorldMatrix);
        _raymarchMaterial.SetFloat("_MaxDistance", _maxDistance);
        _raymarchMaterial.SetInt("_MaxIterations", _maxIterations);
        _raymarchMaterial.SetFloat("_Accuracy", _accuracy);

        _raymarchMaterial.SetVector("_Sphere", _sphere);
        _raymarchMaterial.SetColor("_SphereColor", _sphereColor);
        _raymarchMaterial.SetFloat("_SmoothFactor", _smoothFactor);
        _raymarchMaterial.SetFloat("_BlendFactor", _blendFactor);

        _raymarchMaterial.SetVector("_LightPosition", _light.transform.position);
        _raymarchMaterial.SetColor("_LightColor", _light.color);
        _raymarchMaterial.SetFloat("_LightIntensity", _light.intensity);



        _raymarchMaterial.SetFloat("_Density", _density);
        _raymarchMaterial.SetFloat("_StepSize", _stepSize);
        _raymarchMaterial.SetFloat("_ShadowStepSize", _shadowStepSize);
        _raymarchMaterial.SetFloat("_AnisotropyForward", _anisotropyForward);
        _raymarchMaterial.SetFloat("_AnisotropyBackward", _anisotropyBackward);
        _raymarchMaterial.SetFloat("_LobeWeight", _lobeWeight);
        _raymarchMaterial.SetFloat("_ExponentialFactor", _exponentialFactor);



        RenderTexture.active = destination;
        _raymarchMaterial.SetTexture("_MainTex", source);
        GL.PushMatrix();
        GL.LoadOrtho();
        _raymarchMaterial.SetPass(0);
        GL.Begin(GL.QUADS);

        //Bottom Left
        GL.MultiTexCoord2(0, 0.0f, 0.0f);
        GL.Vertex3(0.0f, 0.0f, 3.0f);

        //Bottom Right
        GL.MultiTexCoord2(0, 1.0f, 0.0f);
        GL.Vertex3(1.0f, 0.0f, 2.0f);

        //Top Right
        GL.MultiTexCoord2(0, 1.0f, 1.0f);
        GL.Vertex3(1.0f, 1.0f, 1.0f);

        //Top Left
        GL.MultiTexCoord2(0, 0.0f, 1.0f);
        GL.Vertex3(0.0f, 1.0f, 0.0f);

        GL.End();
        GL.PopMatrix();

    }

    private Matrix4x4 CamFrustum(Camera cam)
    {
        Matrix4x4 frustum = Matrix4x4.identity;
        float fov = Mathf.Tan((cam.fieldOfView * 0.5f) * Mathf.Deg2Rad);

        Vector3 goUp = Vector3.up * fov;
        Vector3 goRight = Vector3.right * fov * cam.aspect;

        Vector3 topLeft = (-Vector3.forward - goRight + goUp);
        Vector3 topRight = (-Vector3.forward + goRight + goUp);
        Vector3 bottomRight = (-Vector3.forward + goRight - goUp);
        Vector3 bottomLeft = (-Vector3.forward - goRight - goUp);

        frustum.SetRow(0, topLeft);
        frustum.SetRow(1, topRight);
        frustum.SetRow(2, bottomRight);
        frustum.SetRow(3, bottomLeft);


        return frustum;
    }
}