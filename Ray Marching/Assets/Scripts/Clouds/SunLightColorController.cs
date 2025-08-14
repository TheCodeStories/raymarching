using UnityEngine;
using UnityEngine.InputSystem;

[ExecuteAlways]
[RequireComponent(typeof(Light))]
public class SunlightColorController : MonoBehaviour
{
    [Header("Sun Color Settings")]
    public Gradient sunColorGradient;

    [Header("Rotation Settings")]
    public float rotationSpeed = 1f; 

    [Header("Debug")]
    [Range(-1f, 1f)]
    public float sunDot = 0f;

    private Light directionalLight;

    private bool isRotating = false;
    private Quaternion startRot;
    private Quaternion endRot;
    private float rotationProgress = 0f;

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

        if (Keyboard.current != null && Keyboard.current.spaceKey.wasPressedThisFrame && !isRotating)
        {
            startRot = Quaternion.Euler(1f, 0f, 0f);
            endRot = Quaternion.Euler(180f, 0f, 0f);
            rotationProgress = 0f;
            isRotating = true;
        }

        if (isRotating)
        {
            rotationProgress += Time.deltaTime / Mathf.Max(0.01f, rotationSpeed);
            transform.rotation = Quaternion.Slerp(startRot, endRot, rotationProgress);

            if (rotationProgress >= 1f)
                isRotating = false;
        }

        Vector3 sunDirection = transform.forward;

        sunDot = Vector3.Dot(sunDirection, Vector3.down);

        float t = Mathf.InverseLerp(-1f, 1f, sunDot);
        t = Mathf.Clamp01(t);

        Color sunColor = sunColorGradient.Evaluate(t);

        directionalLight.color = sunColor;

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
                    new GradientColorKey(new Color(0f, 0f, 0f), 0.0f),
                    new GradientColorKey(new Color(0.8f, 0.3f, 0.1f), 0.25f),
                    new GradientColorKey(new Color(1f, 1f, 1f), 0.5f),
                    new GradientColorKey(new Color(0.8f, 0.3f, 0.1f), 0.75f),
                    new GradientColorKey(new Color(0f, 0f, 0f), 1.0f)
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
