using UnityEngine;

[ExecuteInEditMode]
public class NoiseGenerator : MonoBehaviour
{
    public int size = 128;
    public RenderTexture texture;
    public ComputeShader shader;

    [Range(0, 100)] public float _scale;
    public float _boost;
    [Range(1, 10)] public int _octaves;
    [Range(1, 32)] public int _tileSize;

    [Range(0, 1)] public float _slice = 0f; // Which Z slice to preview
    public bool _debugPreview = false;

    [Range(1, 8)] public float _debugSize;

    private bool _needsRebuild = true;


    void OnEnable()
    {
        InitTexture();
    }
    void OnValidate() { _needsRebuild = true; }
    void Update()
    {
        if (_needsRebuild)
        {
            InitTexture();
            _needsRebuild = false;
        }
    }

    void InitTexture()
    {
        if (!SystemInfo.supports3DTextures || !SystemInfo.supportsComputeShaders)
        {
            Debug.LogError("3D Textures or compute shaders not supported on this device.");
            return;
        }
        if (texture != null)
        {
            texture.Release();
            texture = null;
        }

        texture = new RenderTexture(size, size, 0)
        {
            dimension = UnityEngine.Rendering.TextureDimension.Tex3D,
            volumeDepth = size,
            enableRandomWrite = true,
            wrapMode = TextureWrapMode.Repeat,
            format = RenderTextureFormat.ARGBFloat
        };
        texture.Create();

        DispatchNoise();
    }

    void DispatchNoise()
    {
        shader.SetTexture(0, "Result", texture);
        shader.SetFloat("_Resolution", size);
        shader.SetFloat("_Scale", _scale);
        shader.SetFloat("_Boost", _boost);
        shader.SetInt("_Octaves", _octaves);
        shader.SetInt("_TileSize", _tileSize);

        int kernel = shader.FindKernel("CSMain");
        int threadGroupSize = 8;

        int threadGroupsX = Mathf.CeilToInt((float)size / threadGroupSize);
        int threadGroupsY = Mathf.CeilToInt((float)size / threadGroupSize);
        int threadGroupsZ = Mathf.CeilToInt((float)size / threadGroupSize);

        shader.Dispatch(kernel, threadGroupsX, threadGroupsY, threadGroupsZ);

        Shader.SetGlobalTexture("_Global3DNoise", texture);
    }

    void OnGUI()
    {
        if (!_debugPreview || texture == null) return;

        // Draw the 3D texture as a 2D slice:
        float sliceIndex = Mathf.Clamp01(_slice) * (size - 1);
        int intSlice = Mathf.RoundToInt(sliceIndex);

        // Blit that slice to a temporary 2D RenderTexture:
        RenderTexture temp = RenderTexture.GetTemporary(size, size, 0, RenderTextureFormat.ARGBFloat);
        Graphics.CopyTexture(texture, intSlice, 0, temp, 0, 0);

        // Draw it on screen:
        GUI.DrawTexture(new Rect(10, 10, 256 * _debugSize, 256 * _debugSize), temp, ScaleMode.ScaleToFit, false);

        RenderTexture.ReleaseTemporary(temp);
    }
}
