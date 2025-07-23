using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[RequireComponent(typeof(Camera))]
[ExecuteInEditMode]
public class BlackholeCamera : MonoBehaviour
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

    [Range(0.0f, 1.0f)]
    public float _stepSize;

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


    private void OnRenderImage(RenderTexture source, RenderTexture destination)
    {
        _camera.allowHDR = true;
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
        _raymarchMaterial.SetVector("_Cylinder", _cylinder);
        _raymarchMaterial.SetColor("_CylinderColor", _cylinderColor);
        _raymarchMaterial.SetFloat("_StepSize", _stepSize);
        _raymarchMaterial.SetFloat("_BlackHoleMass", _blackHoleMass);
        _raymarchMaterial.SetTexture("_CubeMap", _skyboxCubemap);

        _raymarchMaterial.SetColor("_MainGlowColor", _mainGlowColor);
        _raymarchMaterial.SetFloat("_MainGlowWidth", _mainGlowWidth);
        _raymarchMaterial.SetFloat("_MainGlowSharpness", _mainGlowSharpness);
        _raymarchMaterial.SetFloat("_GlowIntensity", _glowIntensity);
        _raymarchMaterial.SetFloat("_Falloff", _falloff);
        _raymarchMaterial.SetFloat("_GlowLimit", _glowLimit);
        _raymarchMaterial.SetFloat("_RotationSpeed", _rotationSpeed);

        // Directly blit using HDR pipeline and let Unity handle the active RT
        Graphics.Blit(source, destination, _raymarchMaterial);
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