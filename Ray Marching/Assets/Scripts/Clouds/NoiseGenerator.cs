using Unity.VisualScripting;
using UnityEngine;

[ExecuteInEditMode]
public class NoiseGenerator : MonoBehaviour
{
    public int size = 256; // Size of the square texture
    public RenderTexture texture;

    public ComputeShader shader;

    [Range(0, 1)]
    public float _scale;
    public float _boost;
    [Range(1, 10)]
    public int _octaves;

    public float _tileSize;

    void OnValidate()
    {
        // Create a new texture
        texture = new RenderTexture(size, size, 32);

        texture.enableRandomWrite = true;
        texture.Create();

        shader.SetTexture(0, "Result", texture);
        shader.Dispatch(0, texture.width / 8, texture.height / 8, 1);
    }

    private void OnRenderImage(RenderTexture source, RenderTexture destination)
    {
        if (texture == null)
        {
            texture = new RenderTexture(size, size, 24);
            texture.enableRandomWrite = true;
            texture.Create();
        }

        shader.SetTexture(0, "Result", texture);
        shader.SetFloat("_Resolution", texture.width);
        shader.SetFloat("_Scale", _scale);
        shader.SetFloat("_Boost", _boost);
        shader.SetInt("_Octaves", _octaves);
        shader.SetFloat("_TileSize", _tileSize);
        shader.Dispatch(0, texture.width / 8, texture.height / 8, 1);

        Graphics.Blit(texture, destination);
    }

}
