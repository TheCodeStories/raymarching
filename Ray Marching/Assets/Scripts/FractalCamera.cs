using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[RequireComponent(typeof(Camera))]
[ExecuteInEditMode]
public class FractalCamera : MonoBehaviour
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

    public Transform _directionalLight;


    private Camera _cam;

    public float _maxDistance;
    public float _power;
    public float _darkness;
    public float _blackAndWhite;
    public Vector3 _colourAMix;
    public Vector3 _colourBMix;
    public int _iterations;

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
        _raymarchMaterial.SetVector("_LightDirection", _directionalLight ? _directionalLight.forward : Vector3.down);

        _raymarchMaterial.SetFloat("_Power", _power);
        _raymarchMaterial.SetFloat("_Darkness", _darkness);
        _raymarchMaterial.SetFloat("_BlackAndWhite", _blackAndWhite);
        _raymarchMaterial.SetVector("_ColourAMix", _colourAMix);
        _raymarchMaterial.SetVector("_ColourBMix", _colourBMix);
        _raymarchMaterial.SetInt("_Iterations", _iterations);



        RenderTexture.active = destination;

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