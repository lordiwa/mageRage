using UnityEngine;

public class CameraFollow : MonoBehaviour
{
    [Header("Follow Settings")]
    public Transform target; // Drag your Player here
    public Vector3 offset = new Vector3(0, 0, -10);
    public float smoothTime = 0.3f;
    
    private Vector3 velocity = Vector3.zero;
    
    void LateUpdate()
    {
        if (target != null)
        {
            Vector3 targetPosition = target.position + offset;
            transform.position = Vector3.SmoothDamp(transform.position, targetPosition, ref velocity, smoothTime);
        }
    }
}