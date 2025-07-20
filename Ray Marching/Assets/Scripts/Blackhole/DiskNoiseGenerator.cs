using UnityEngine;

[ExecuteAlways] // Makes it run in edit mode too
public class DiskNoiseGenerator : MonoBehaviour
{
    public ComputeShader computeShader;
    [Range(1, 4000)]
    public int resolution = 512;

    private RenderTexture outputTexture;
    private int lastResolution = -1;

    void OnEnable()
    {
        GenerateTexture(); // Run when script (re)enabled
    }

    void OnValidate()
    {
        // Only regenerate if resolution actually changed
        if (resolution != lastResolution)
        {
            GenerateTexture();
        }
    }

    void GenerateTexture()
    {
        if (outputTexture != null)
        {
            outputTexture.Release();
            DestroyImmediate(outputTexture);
        }

        // Clamp to safe range:
        int safeRes = Mathf.Max(1, resolution);
        int threadGroupSize = 8;
        int dispatchX = Mathf.CeilToInt(safeRes / (float)threadGroupSize);
        int dispatchY = Mathf.CeilToInt(safeRes / (float)threadGroupSize);

        outputTexture = new RenderTexture(safeRes, safeRes, 0)
        {
            enableRandomWrite = true,
            filterMode = FilterMode.Bilinear,
            wrapMode = TextureWrapMode.Repeat
        };
        outputTexture.Create();

        if (!outputTexture.IsCreated())
        {
            Debug.LogError("Failed to create RenderTexture!");
            return;
        }

        int kernelHandle = computeShader.FindKernel("CSMain");
        computeShader.SetTexture(kernelHandle, "_DiskNoise", outputTexture);
        computeShader.SetVector("_Resolution", new Vector2(safeRes, safeRes));
        computeShader.Dispatch(kernelHandle, dispatchX, dispatchY, 1);

        Shader.SetGlobalTexture("_DiskNoise", outputTexture);
        lastResolution = safeRes;
    }

    void OnDisable()
    {
        if (outputTexture != null)
        {
            outputTexture.Release();
            DestroyImmediate(outputTexture);
        }
    }

    // void OnGUI()
    // {
    //     if (outputTexture != null)
    //         GUI.DrawTexture(new Rect(10, 10, 256, 256), outputTexture, ScaleMode.ScaleToFit, false);
    // }
}