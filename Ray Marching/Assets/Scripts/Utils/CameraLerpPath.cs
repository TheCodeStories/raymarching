using UnityEngine;
using UnityEngine.InputSystem; // <-- new input system namespace
using System.Collections.Generic;

public class CameraLerpPath : MonoBehaviour
{
    [System.Serializable]
    public class PathPoint
    {
        public Vector3 position;
        public Vector3 eulerRotation;  // Set this in the Inspector
        public float duration = 1f;

        public Quaternion Rotation => Quaternion.Euler(eulerRotation);
    }

    public List<PathPoint> pathPoints = new List<PathPoint>();
    public Key triggerKey = Key.Space;

    private bool isLerping = false;
    private int currentPoint = 0;
    private float t = 0f;

    private Vector3 startPos;
    private Quaternion startRot;

    void Start()
    {

    }

    void Update()
    {
        if (Keyboard.current[triggerKey].wasPressedThisFrame && pathPoints.Count > 1)
        {
            transform.position = pathPoints[0].position;
            transform.rotation = Quaternion.Euler(pathPoints[0].eulerRotation);
            currentPoint = 1;
            startPos = transform.position;
            startRot = transform.rotation;
            t = 0f;
            isLerping = true;
        }

        if (isLerping)
        {
            PathPoint target = pathPoints[currentPoint];
            t += Time.deltaTime / target.duration;

            // float easedT = EaseInOut(t);
            float easedT = t;
            transform.position = Vector3.Slerp(startPos, target.position, easedT);
            transform.rotation = Quaternion.Slerp(startRot, target.Rotation, easedT);

            if (t >= 1f)
            {
                currentPoint++;
                if (currentPoint >= pathPoints.Count)
                {
                    isLerping = false;
                }
                else
                {
                    startPos = transform.position;
                    startRot = transform.rotation;
                    t = 0f;
                }
            }
        }
    }

    float EaseInOut(float x)
    {
        return x * x * (3f - 2f * x);
    }
}
