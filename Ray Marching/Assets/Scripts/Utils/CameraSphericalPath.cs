using UnityEngine;
using UnityEngine.InputSystem;
using System.Collections.Generic;

public class CameraSphericalPath : MonoBehaviour
{
    [Tooltip("World-space positions the camera should move through.")]
    public List<Vector3> pathPoints = new List<Vector3>();

    public Key triggerKey = Key.Space;
    public float speed = 5f; // world units per second
    public Vector3 sphereCenter = Vector3.zero;

    private List<float> segmentLengths = new List<float>();
    private float totalLength;
    private float distanceTraveled;
    private bool isMoving;

    void Start()
    {
        if (pathPoints.Count >= 2)
            PrecomputeSegmentLengths();
    }

    void Update()
    {
        if (Keyboard.current[triggerKey].wasPressedThisFrame && pathPoints.Count >= 2)
        {
            distanceTraveled = 0f;
            isMoving = true;
        }

        if (!isMoving) return;

        distanceTraveled += speed * Time.deltaTime;

        if (distanceTraveled >= totalLength)
        {
            distanceTraveled = totalLength;
            isMoving = false;
        }

        // Find which segment we are in
        float traveled = 0f;
        int seg = 0;
        while (seg < segmentLengths.Count &&
               traveled + segmentLengths[seg] < distanceTraveled)
        {
            traveled += segmentLengths[seg];
            seg++;
        }
        if (seg >= segmentLengths.Count) seg = segmentLengths.Count - 1;

        float localT = (distanceTraveled - traveled) / segmentLengths[seg];

        // Get start and end positions (relative to sphere center)
        Vector3 start = pathPoints[seg] - sphereCenter;
        Vector3 end = pathPoints[seg + 1] - sphereCenter;
        float radius = start.magnitude;

        // Current position
        Vector3 pos = SphericalInterpolate(start.normalized, end.normalized, localT) * radius;
        transform.position = sphereCenter + pos;

        // Tangent direction (look ahead a bit)
        float dt = 0.001f;
        float lookT = Mathf.Clamp01(localT + dt);
        Vector3 lookPos = SphericalInterpolate(start.normalized, end.normalized, lookT) * radius;
        Vector3 tangent = (lookPos - pos).normalized;

        // Up = radial from sphere center
        Vector3 up = pos.normalized;

        transform.rotation = Quaternion.LookRotation(tangent, up);
    }

    void PrecomputeSegmentLengths(int resolution = 20)
    {
        segmentLengths.Clear();
        totalLength = 0f;

        for (int i = 0; i < pathPoints.Count - 1; i++)
        {
            Vector3 a = pathPoints[i] - sphereCenter;
            Vector3 b = pathPoints[i + 1] - sphereCenter;
            float radius = a.magnitude;

            float length = 0f;
            Vector3 prev = SphericalInterpolate(a.normalized, b.normalized, 0f) * radius;
            for (int j = 1; j <= resolution; j++)
            {
                float t = j / (float)resolution;
                Vector3 next = SphericalInterpolate(a.normalized, b.normalized, t) * radius;
                length += Vector3.Distance(prev, next);
                prev = next;
            }

            segmentLengths.Add(length);
            totalLength += length;
        }
    }

    Vector3 SphericalInterpolate(Vector3 a, Vector3 b, float t)
    {
        float dot = Mathf.Clamp(Vector3.Dot(a, b), -1f, 1f);
        float theta = Mathf.Acos(dot) * t;
        Vector3 relativeVec = (b - a * dot).normalized;
        return a * Mathf.Cos(theta) + relativeVec * Mathf.Sin(theta);
    }
}
