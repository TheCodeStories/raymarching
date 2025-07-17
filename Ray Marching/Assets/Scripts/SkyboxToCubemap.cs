using UnityEngine;

public class SkyboxToCubemap : MonoBehaviour
{
    public int cubemapSize = 512;
    public Material raymarchMat;

    private Cubemap dynamicCube;

    void Start()
    {
        dynamicCube = new Cubemap(cubemapSize, TextureFormat.RGB24, false);

        // Renders the skybox only to the cubemap.
        Camera cam = GetComponent<Camera>();
        cam.RenderToCubemap(dynamicCube);

        raymarchMat.SetTexture("_Cube", dynamicCube);
    }
}
