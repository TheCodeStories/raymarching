using UnityEngine;

[ExecuteAlways]
[RequireComponent(typeof(Light))]
public class SunlightColorController : MonoBehaviour
{
    [Header("Sun Color Settings")]
    public Gradient sunColorGradient;

    [Header("Debug")]
    [Range(-1f, 1f)]
    public float sunDot = 0f;

    private Light directionalLight;

    void OnValidate()
    {
        SetupGradient();
    }

    void Awake()
    {
        directionalLight = GetComponent<Light>();
        SetupGradient();
    }

    void Update()
    {
        if (directionalLight == null)
            directionalLight = GetComponent<Light>();

        // Calculate sun position relative to "up" (Vector3.up)
        Vector3 sunDirection = transform.forward; // In Unity, directional light shines along its forward
        sunDot = Vector3.Dot(sunDirection, Vector3.down); 
        // sunDot: +1 = noon (directly overhead), -1 = midnight (below horizon)

        // Remap dot from [-1, 1] to [0, 1]
        float t = Mathf.InverseLerp(-0.1f, 1f, sunDot);
        t = Mathf.Clamp01(t);

        // Evaluate color from gradient
        Color sunColor = sunColorGradient.Evaluate(t);

        directionalLight.color = sunColor;
    }

    private void SetupGradient()
    {
        // If no gradient set, create a default one
        if (sunColorGradient == null || sunColorGradient.colorKeys.Length == 0)
        {
            sunColorGradient = new Gradient();
            sunColorGradient.SetKeys(
                new GradientColorKey[]
                {
                    new GradientColorKey(new Color(0.8f, 0.3f, 0.1f), 0.0f), // Sunrise/Sunset: orange/red
                    new GradientColorKey(new Color(1.0f, 0.95f, 0.8f), 0.5f), // Mid-elevation: warm white
                    new GradientColorKey(new Color(1.0f, 1.0f, 1.0f), 1.0f)   // Noon: white
                },
                new GradientAlphaKey[]
                {
                    new GradientAlphaKey(1.0f, 0.0f),
                    new GradientAlphaKey(1.0f, 1.0f)
                }
            );
        }
    }
}
