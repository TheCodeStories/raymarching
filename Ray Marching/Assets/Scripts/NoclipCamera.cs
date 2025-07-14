using UnityEngine;
using UnityEngine.InputSystem;

[RequireComponent(typeof(Camera))]
public class NoclipCamera : MonoBehaviour
{
    [Header("Movement")]
    public float movementSpeed = 5f;
    public float fastSpeedMultiplier = 3f;

    [Header("Mouse Look")]
    public float mouseSensitivity = 2f;

    private float yaw = 0f;
    private float pitch = 0f;

    private Vector2 lookDelta;
    private bool isLooking = false;

    private void Start()
    {
        Vector3 angles = transform.eulerAngles;
        yaw = angles.y;
        pitch = angles.x;
    }

    private void Update()
    {
        HandleMouseLook();
        HandleMovement();
    }

    private void HandleMouseLook()
    {
        if (Mouse.current.leftButton.isPressed)
        {
            isLooking = true;
            Vector2 delta = Mouse.current.delta.ReadValue();
            lookDelta = delta * mouseSensitivity;

            yaw += lookDelta.x;
            pitch -= lookDelta.y;
            pitch = Mathf.Clamp(pitch, -90f, 90f);

            transform.rotation = Quaternion.Euler(pitch, yaw, 0f);
        }
        else
        {
            isLooking = false;
        }
    }

    private void HandleMovement()
    {
        Vector3 move = Vector3.zero;
        Keyboard kb = Keyboard.current;

        if (kb.wKey.isPressed) move += transform.forward;
        if (kb.sKey.isPressed) move -= transform.forward;
        if (kb.aKey.isPressed) move -= transform.right;
        if (kb.dKey.isPressed) move += transform.right;
        if (kb.qKey.isPressed) move -= transform.up;
        if (kb.eKey.isPressed) move += transform.up;

        float speed = movementSpeed;
        if (kb.leftShiftKey.isPressed)
            speed *= fastSpeedMultiplier;

        transform.position += move * speed * Time.deltaTime;
    }
}
