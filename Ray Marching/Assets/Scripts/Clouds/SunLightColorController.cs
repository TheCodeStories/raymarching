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

        // Directional light shines along its forward
        Vector3 sunDirection = transform.forward;

        // +1 = overhead, -1 = under horizon
        sunDot = Vector3.Dot(sunDirection, Vector3.down);

        // Map [-1,1] → [0,1]
        float t = Mathf.InverseLerp(-1f, 1f, sunDot);
        t = Mathf.Clamp01(t);

        // Evaluate gradient
        Color sunColor = sunColorGradient.Evaluate(t);

        directionalLight.color = sunColor;

        // Optional: disable light completely at night (if you want no light at all)
        directionalLight.enabled = sunColor.maxColorComponent > 0.01f;
    }

    private void SetupGradient()
    {
        if (sunColorGradient == null || sunColorGradient.colorKeys.Length == 0)
        {
            sunColorGradient = new Gradient();
            sunColorGradient.SetKeys(
                new GradientColorKey[]
                {
                    new GradientColorKey(new Color(0f, 0f, 0f), 0.0f),         // Midnight: black
                    new GradientColorKey(new Color(0.8f, 0.3f, 0.1f), 0.25f),  // Sunrise: orange/red
                    new GradientColorKey(new Color(1f, 1f, 1f), 0.5f),         // Noon: white
                    new GradientColorKey(new Color(0.8f, 0.3f, 0.1f), 0.75f),  // Sunset: orange/red
                    new GradientColorKey(new Color(0f, 0f, 0f), 1.0f)          // Midnight again: black
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
