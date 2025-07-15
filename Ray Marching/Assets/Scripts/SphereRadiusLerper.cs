using UnityEngine;
using UnityEngine.InputSystem; // Required for the new Input System

public class SphereRadiusLerper : MonoBehaviour
{
    public RaymarchCamera raymarchCam;

    public float targetRadius = 1.0f;
    public float lerpSpeed = 1.0f;
    public Key triggerKey = Key.R;

    private bool isLerping = false;
    private float initialRadius;
    private float t;

    void Update()
    {
        if (raymarchCam == null)
        {
            Debug.LogWarning("RaymarchCamera reference not assigned.");
            return;
        }

        if (Keyboard.current[triggerKey].wasPressedThisFrame)
        {
            initialRadius = raymarchCam._sphere.w;
            t = 0f;
            isLerping = true;
        }

        if (isLerping)
        {
            t += Time.deltaTime * lerpSpeed;
            float easedT = EaseInOut(t);

            float newRadius = Mathf.Lerp(initialRadius, targetRadius, easedT);
            Vector4 sphere = raymarchCam._sphere;
            sphere.w = newRadius;
            raymarchCam._sphere = sphere;

            if (t >= 1f)
            {
                isLerping = false;
            }
        }
    }

    float EaseInOut(float x)
    {
        return x * x * (3f - 2f * x); // Smoothstep
    }
}
