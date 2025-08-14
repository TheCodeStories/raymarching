
using UnityEngine;
using UnityEditor;

public class CubemapCreator
{
    [MenuItem("Tools/Create Cubemap From 4K Textures")]
    static void CreateCubemap()
    {
        string basePath = "Assets/SpaceSkies Free/Skybox_3/Textures/4K_Resolution/";
        Texture2D right = AssetDatabase.LoadAssetAtPath<Texture2D>(basePath + "Right_4K_TEX.png");
        Texture2D left  = AssetDatabase.LoadAssetAtPath<Texture2D>(basePath + "Left_4K_TEX.png");
        Texture2D down    = AssetDatabase.LoadAssetAtPath<Texture2D>(basePath + "Up_4K_TEX.png");
        Texture2D up  = AssetDatabase.LoadAssetAtPath<Texture2D>(basePath + "Down_4K_TEX.png");
        Texture2D back = AssetDatabase.LoadAssetAtPath<Texture2D>(basePath + "Front_4K_TEX.png");
        Texture2D front  = AssetDatabase.LoadAssetAtPath<Texture2D>(basePath + "Back_4K_TEX.png");

        if (!right || !left || !up || !down || !front || !back)
        {
            Debug.LogError("One or more textures could not be found. Check the file paths and names.");
            return;
        }

        int size = right.width;
        Cubemap cubemap = new Cubemap(size, TextureFormat.RGBA32, false);

        cubemap.SetPixels(right.GetPixels(), CubemapFace.PositiveX);
        cubemap.SetPixels(left.GetPixels(), CubemapFace.NegativeX);
        cubemap.SetPixels(up.GetPixels(), CubemapFace.PositiveY);
        cubemap.SetPixels(down.GetPixels(), CubemapFace.NegativeY);
        cubemap.SetPixels(front.GetPixels(), CubemapFace.PositiveZ);
        cubemap.SetPixels(back.GetPixels(), CubemapFace.NegativeZ);

        cubemap.Apply();

        AssetDatabase.CreateAsset(cubemap, basePath + "GeneratedCubemap.cubemap");
        AssetDatabase.SaveAssets();

        Debug.Log("✅ Cubemap created at Assets/GeneratedCubemap.cubemap");
    }
}
