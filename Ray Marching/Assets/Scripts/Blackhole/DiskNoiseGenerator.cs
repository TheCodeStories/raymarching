using UnityEngine;

[ExecuteInEditMode]
public class DiskNoiseGenerator : MonoBehaviour
{
    public Vector3Int resolution;
    public RenderTexture texture;
    public ComputeShader shader;

    [Range(0, 100)] public float _scale;
    public float _boost;
    [Range(1, 10)] public int _octaves;
    [Range(1, 32)] public int _tileSize;
    public float _swirlStrength;
    public float _verticalScale;
    public float _maxRadius;

    [Range(0, 1)] public float _slice = 0f;
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

        texture = new RenderTexture(resolution.x, resolution.y, 0, RenderTextureFormat.RFloat)
        {
            dimension = UnityEngine.Rendering.TextureDimension.Tex3D,
            volumeDepth = resolution.z,
            enableRandomWrite = true,

            useMipMap = true,
            autoGenerateMips = false,
            filterMode = FilterMode.Trilinear,
            wrapMode = TextureWrapMode.Repeat,
            anisoLevel = 8
        };
        texture.Create();

        DispatchNoise();

        texture.GenerateMips();
    }

    void DispatchNoise()
    {
        shader.SetTexture(0, "Result", texture);
        shader.SetInts("_Resolution", resolution.x,resolution.y,resolution.z);
        shader.SetFloat("_Scale", _scale);
        shader.SetFloat("_Boost", _boost);
        shader.SetInt("_Octaves", _octaves);
        shader.SetInt("_TileSize", _tileSize);
        shader.SetFloat("_SwirlStrength", _swirlStrength);    // swirl twist
        shader.SetFloat("_VerticalScale", _verticalScale);    // disk flatness
        shader.SetFloat("_MaxRadius", _maxRadius);        // for falloff normalization

        int kernel = shader.FindKernel("CSMain");
        int threadGroupSize = 8;

        int threadGroupsX = Mathf.CeilToInt((float)resolution.x / threadGroupSize);
        int threadGroupsY = Mathf.CeilToInt((float)resolution.y / threadGroupSize);
        int threadGroupsZ = Mathf.CeilToInt((float)resolution.z / threadGroupSize);

        shader.Dispatch(kernel, threadGroupsX, threadGroupsY, threadGroupsZ);

        Shader.SetGlobalTexture("_Global3DNoise", texture);
    }

    // void OnGUI()
    // {
    //     if (!_debugPreview || texture == null) return;

    //     // Draw the 3D texture as a 2D slice:
    //     float sliceIndex = Mathf.Clamp01(_slice) * (resolution - 1);
    //     int intSlice = Mathf.RoundToInt(sliceIndex);

    //     RenderTexture temp = RenderTexture.GetTemporary(resolution, resolution, 0, RenderTextureFormat.RFloat);
    //     Graphics.CopyTexture(texture, intSlice, 0, temp, 0, 0);

    //     GUI.DrawTexture(new Rect(10, 10, 256 * _debugSize, 256 * _debugSize), temp, ScaleMode.ScaleToFit, false);

    //     RenderTexture.ReleaseTemporary(temp);
    // }
}
