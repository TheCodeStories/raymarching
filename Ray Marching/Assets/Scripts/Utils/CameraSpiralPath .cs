using UnityEngine;
using UnityEngine.InputSystem;

public class CameraSpiralPath : MonoBehaviour
{
    public Key triggerKey = Key.Space;
    public float speed = 1f;
    public float startRadius = 20f;
    public float decayRate = 0.5f;
    public float totalTurns = 5f;
    public float totalFallDistance = 20f;
    public bool alwaysLookAtOrigin = false;

    [Range(-89f, 89f)]
    public float tiltAngle = 0f; // Tilt in degrees relative to vertical (X-axis tilt)

    private float t = 0f;
    private bool isFalling = false;

    // Persistent up vector to avoid flips
    private Vector3 stableUp = Vector3.up;

    void Update()
    {
        if (Keyboard.current[triggerKey].wasPressedThisFrame)
        {
            t = 0f;
            isFalling = true;
            stableUp = Vector3.up; // reset
        }

        if (!isFalling) return;

        t += (speed / totalTurns) * Time.deltaTime;
        if (t >= 1f)
        {
            isFalling = false;
            return;
        }

        Vector3 currentPos = GetSpiralPosition(t);
        transform.position = currentPos;

        if (alwaysLookAtOrigin)
        {
            Vector3 forward = (Vector3.zero - currentPos).normalized;

            Vector3 projectedUp = stableUp - forward * Vector3.Dot(forward, stableUp);
            if (projectedUp.sqrMagnitude < 0.0001f)
                projectedUp = Vector3.Cross(forward, Vector3.right);

            stableUp = Vector3.Slerp(stableUp, projectedUp.normalized, Time.deltaTime * 5f);
            transform.rotation = Quaternion.LookRotation(forward, stableUp);
        }
        else
        {
            Vector3 futurePos = GetSpiralPosition(t + 0.01f);
            Vector3 pastPos = GetSpiralPosition(t - 0.01f);

            Vector3 forward = (futurePos - currentPos).normalized;
            Vector3 backward = (currentPos - pastPos).normalized;

            Vector3 right = Vector3.Cross(forward, backward).normalized;
            Vector3 up = Vector3.Cross(right, forward).normalized;

            transform.rotation = Quaternion.LookRotation(forward, up);
        }
    }

    Vector3 GetSpiralPosition(float t)
    {
        float angle = t * totalTurns * Mathf.PI * 2f;
        float radius = startRadius * Mathf.Exp(-decayRate * t);

        float z = Mathf.Cos(angle) * radius;
        float y = Mathf.Sin(angle) * radius;

        Vector3 pos = new Vector3(0, y, z);

        // Apply tilt around the Z-axis (so "vertical" is slanted)
        Quaternion tiltRotation = Quaternion.AngleAxis(tiltAngle, Vector3.forward);
        pos = tiltRotation * pos;

        return pos;
    }
}








// using UnityEngine;
// using UnityEngine.InputSystem;

// public class CameraSpiralPath : MonoBehaviour
// {
//     public Key triggerKey = Key.Space;
//     public float speed = 1f;
//     public float startRadius = 20f;
//     public float decayRate = 0.5f;
//     public float totalTurns = 5f;
//     public float totalFallDistance = 20f;
//     public bool alwaysLookAtOrigin = false;

//     [Tooltip("When true, keeps the camera horizon level even when looking at the origin.")]
//     public bool keepHorizonLevel = false;

//     [Range(-89f, 89f)]
//     public float tiltAngle = 0f; // Tilt in degrees relative to vertical (X-axis tilt)

//     private float t = 0f;
//     private bool isFalling = false;

//     // Persistent up vector to avoid flips
//     private Vector3 stableUp = Vector3.up;

//     void Update()
//     {
//         if (Keyboard.current[triggerKey].wasPressedThisFrame)
//         {
//             t = 0f;
//             isFalling = true;
//             stableUp = Vector3.up; // reset
//         }

//         if (!isFalling) return;

//         t += (speed / totalTurns) * Time.deltaTime;
//         if (t >= 1f)
//         {
//             isFalling = false;
//             return;
//         }

//         Vector3 currentPos = GetSpiralPosition(t);
//         transform.position = currentPos;

//         if (alwaysLookAtOrigin)
//         {
//             Vector3 forward = (Vector3.zero - currentPos).normalized;

//             if (keepHorizonLevel)
//             {
//                 // Lock up vector to world up (Y-axis) projected to be perpendicular to forward
//                 Vector3 horizUp = Vector3.ProjectOnPlane(Vector3.up, forward).normalized;
//                 transform.rotation = Quaternion.LookRotation(forward, horizUp);
//             }
//             else
//             {
//                 // Smooth stable-up mode (original behavior)
//                 Vector3 projectedUp = stableUp - forward * Vector3.Dot(forward, stableUp);
//                 if (projectedUp.sqrMagnitude < 0.0001f)
//                     projectedUp = Vector3.Cross(forward, Vector3.right);

//                 stableUp = Vector3.Slerp(stableUp, projectedUp.normalized, Time.deltaTime * 5f);
//                 transform.rotation = Quaternion.LookRotation(forward, stableUp);
//             }
//         }
//         else
//         {
//             Vector3 futurePos = GetSpiralPosition(t + 0.01f);
//             Vector3 pastPos = GetSpiralPosition(t - 0.01f);

//             Vector3 forward = (futurePos - currentPos).normalized;
//             Vector3 backward = (currentPos - pastPos).normalized;

//             Vector3 right = Vector3.Cross(forward, backward).normalized;
//             Vector3 up = Vector3.Cross(right, forward).normalized;

//             transform.rotation = Quaternion.LookRotation(forward, up);
//         }
//     }

//     Vector3 GetSpiralPosition(float t)
//     {
//         float angle = t * totalTurns * Mathf.PI * 2f;
//         float radius = startRadius * Mathf.Exp(-decayRate * t);

//         float z = Mathf.Cos(angle) * radius;
//         float y = Mathf.Sin(angle) * radius;

//         Vector3 pos = new Vector3(0, y, z);

//         // Apply tilt around the Z-axis (so "vertical" is slanted)
//         Quaternion tiltRotation = Quaternion.AngleAxis(tiltAngle, Vector3.forward);
//         pos = tiltRotation * pos;

//         return pos;
//     }
// }
