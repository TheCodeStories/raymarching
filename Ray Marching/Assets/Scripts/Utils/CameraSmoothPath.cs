using UnityEngine;
using UnityEngine.InputSystem;
using System.Collections.Generic;

public class CameraSmoothPath : MonoBehaviour
{
    [System.Serializable]
    public class PathPoint
    {
        public Vector3 position;
        public Vector3 eulerRotation;
        public float roll = 0f;

        public Quaternion Rotation => Quaternion.Euler(eulerRotation);
    }

    public List<PathPoint> pathPoints = new List<PathPoint>();
    public Key triggerKey = Key.Space;
    public bool alwaysLookAtOrigin = false;
    public float speed = 5f;

    private float distanceTraveled = 0f;
    private float totalLength;
    private bool isMoving = false;
    private List<float> segmentLengths = new List<float>();

    // Persistent up vector for pole-safe lookAt
    private Vector3 stableUp = Vector3.up;

    void Start()
    {
        if (pathPoints.Count < 2)
            return;

        segmentLengths.Clear();
        totalLength = 0f;

        for (int i = 0; i < pathPoints.Count - 1; i++)
        {
            float segmentLength = EstimateSegmentLength(i);
            segmentLengths.Add(segmentLength);
            totalLength += segmentLength;
        }
    }

    void Update()
    {
        if (Keyboard.current[triggerKey].wasPressedThisFrame && pathPoints.Count >= 4)
        {
            distanceTraveled = 0f;
            isMoving = true;
            stableUp = Vector3.up; // reset at start
        }

        if (!isMoving) return;

        distanceTraveled += speed * Time.deltaTime;

        if (distanceTraveled >= totalLength)
        {
            isMoving = false;
            return;
        }

        // Find current segment
        float traveled = 0f;
        int segmentIndex = 0;
        while (segmentIndex < segmentLengths.Count && traveled + segmentLengths[segmentIndex] < distanceTraveled)
        {
            traveled += segmentLengths[segmentIndex];
            segmentIndex++;
        }
        if (segmentIndex >= segmentLengths.Count)
            segmentIndex = segmentLengths.Count - 1;

        float localT = (distanceTraveled - traveled) / segmentLengths[segmentIndex];

        Vector3 pos = GetCatmullRomPosition(segmentIndex, localT);
        transform.position = pos;

        if (alwaysLookAtOrigin)
        {
            Vector3 forward = (-transform.position).normalized;

            // Remove parallel component from stableUp so it's always perpendicular
            Vector3 projectedUp = stableUp - forward * Vector3.Dot(forward, stableUp);
            if (projectedUp.sqrMagnitude < 0.0001f)
                projectedUp = Vector3.Cross(forward, Vector3.right); // fallback

            // Smooth adjust
            stableUp = Vector3.Slerp(stableUp, projectedUp.normalized, Time.deltaTime * 5f);

            transform.rotation = Quaternion.LookRotation(forward, stableUp);
        }
        else
        {
            Quaternion a = pathPoints[segmentIndex].Rotation;
            Quaternion b = pathPoints[segmentIndex + 1].Rotation;
            transform.rotation = Quaternion.Slerp(a, b, localT);
        }
    }

    Vector3 GetCatmullRomPosition(int segmentIndex, float t)
    {
        Vector3 p0 = pathPoints[Mathf.Clamp(segmentIndex - 1, 0, pathPoints.Count - 1)].position;
        Vector3 p1 = pathPoints[Mathf.Clamp(segmentIndex,     0, pathPoints.Count - 1)].position;
        Vector3 p2 = pathPoints[Mathf.Clamp(segmentIndex + 1, 0, pathPoints.Count - 1)].position;
        Vector3 p3 = pathPoints[Mathf.Clamp(segmentIndex + 2, 0, pathPoints.Count - 1)].position;

        return 0.5f * (
            2f * p1 +
            (-p0 + p2) * t +
            (2f * p0 - 5f * p1 + 4f * p2 - p3) * t * t +
            (-p0 + 3f * p1 - 3f * p2 + p3) * t * t * t
        );
    }

    float EstimateSegmentLength(int index, int resolution = 10)
    {
        float length = 0f;
        Vector3 prev = GetCatmullRomPosition(index, 0f);
        for (int i = 1; i <= resolution; i++)
        {
            float t = i / (float)resolution;
            Vector3 point = GetCatmullRomPosition(index, t);
            length += Vector3.Distance(prev, point);
            prev = point;
        }
        return length;
    }
}
