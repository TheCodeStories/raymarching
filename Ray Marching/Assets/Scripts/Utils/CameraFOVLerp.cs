using UnityEngine;
using UnityEngine.InputSystem;

[RequireComponent(typeof(Camera))]
public class CameraFOVLerp : MonoBehaviour
{
    public Key triggerKey = Key.Space;
    public float fovA;     // First FOV value
    public float fovB;       // Second FOV value
    public float lerpSpeed = 3f;   // How fast to lerp

    private Camera cam;
    private bool toB = false;      // Direction of lerp
    private float targetFOV;

    void Start()
    {
        cam = GetComponent<Camera>();
        targetFOV = fovA;
    }

    void Update()
    {
        if (Keyboard.current[triggerKey].wasPressedThisFrame)
        {
            cam.fieldOfView = fovA;
        }

        cam.fieldOfView = Mathf.Lerp(cam.fieldOfView, fovB, Time.deltaTime * lerpSpeed);
    }
}
