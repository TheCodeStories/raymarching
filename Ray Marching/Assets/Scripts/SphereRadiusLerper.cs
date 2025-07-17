using UnityEngine;
using UnityEngine.InputSystem;

public class SphereRadiusLerper : MonoBehaviour
{
    public RaymarchCamera fractalCam;

    public float[] targetRadii = { 1.0f, 0.5f, 2.0f }; // Add more steps as needed
    public float lerpSpeed = 1.0f;
    public Key triggerKey = Key.R;

    private bool isLerping = false;
    private float initialRadius;
    private float t;
    private int currentStep = 0;

    void Update()
    {
        if (fractalCam == null)
        {
            Debug.LogWarning("RaymarchCamera reference not assigned.");
            return;
        }

        if (Keyboard.current[triggerKey].wasPressedThisFrame)
        {
            if (targetRadii.Length == 0)
            {
                Debug.LogWarning("No target radii defined.");
                return;
            }

            currentStep = 0;
            StartLerp();
        }

        if (isLerping)
        {
            t += Time.deltaTime * lerpSpeed;
            float easedT = EaseInOut(t);
            // float easedT = t;

            float newRadius = Mathf.Lerp(initialRadius, targetRadii[currentStep], easedT);
            float boxX = fractalCam._ground;
            boxX = newRadius;
            fractalCam._ground = boxX;

            if (t >= 1f)
            {
                currentStep++;
                if (currentStep < targetRadii.Length)
                {
                    StartLerp();
                }
                else
                {
                    isLerping = false;
                }
            }
        }
    }

    void StartLerp()
    {
        initialRadius = fractalCam._ground;
        t = 0f;
        isLerping = true;
    }

    float EaseInOut(float x)
    {
        return x * x * (3f - 2f * x); // Smoothstep
    }
}
