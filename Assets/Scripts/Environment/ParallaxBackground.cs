using UnityEngine;

public class ParallaxBackground : MonoBehaviour
{
    [System.Serializable]
    public class ParallaxLayer
    {
        [Header("Layer Settings")]
        public Transform layerTransform;
        public float parallaxSpeed = 1f;
        public float layerWidth = 20f;
        
        [System.NonSerialized]
        public Vector3 startPosition;
    }
    
    [Header("Parallax Layers")]
    [SerializeField] private ParallaxLayer[] parallaxLayers = new ParallaxLayer[4];
    
    [Header("Camera Reference")]
    [SerializeField] private Transform cameraTransform;
    
    private Vector3 lastCameraPosition;
    
    void Start()
    {
        // Get camera reference
        if (cameraTransform == null)
        {
            Camera mainCamera = Camera.main;
            if (mainCamera != null)
                cameraTransform = mainCamera.transform;
        }
        
        // Store starting positions for layers
        for (int i = 0; i < parallaxLayers.Length; i++)
        {
            if (parallaxLayers[i].layerTransform != null)
            {
                parallaxLayers[i].startPosition = parallaxLayers[i].layerTransform.position;
            }
        }
        
        // IMPORTANT: Initialize camera position AFTER one frame
        // This prevents the initial camera jump from affecting parallax
        Invoke(nameof(InitializeCameraPosition), 0.1f);
    }

    void InitializeCameraPosition()
    {
        if (cameraTransform != null)
            lastCameraPosition = cameraTransform.position;
    }
    
    void Update()
    {
        if (cameraTransform == null) return;
        
        // Calculate camera movement since last frame
        Vector3 cameraMovement = cameraTransform.position - lastCameraPosition;
        
        // Update each parallax layer
        for (int i = 0; i < parallaxLayers.Length; i++)
        {
            if (parallaxLayers[i].layerTransform == null) continue;
            
            // Move layer based on camera movement and parallax speed
            Vector3 movement = cameraMovement * parallaxLayers[i].parallaxSpeed;
            parallaxLayers[i].layerTransform.position += movement;
            
            // Handle infinite looping
            HandleLooping(i);
        }
        
        // Store camera position for next frame
        lastCameraPosition = cameraTransform.position;
    }
    
    void HandleLooping(int layerIndex)
    {
        ParallaxLayer layer = parallaxLayers[layerIndex];
        Vector3 currentPos = layer.layerTransform.position;
        
        if (cameraTransform != null)
        {
            float cameraX = cameraTransform.position.x;
            float layerWidth = layer.layerWidth;
            
            // Check if sprite has moved too far left (behind camera)
            if (currentPos.x + (layerWidth * 0.5f) < cameraX - 15f)
            {
                currentPos.x += layerWidth;
                layer.layerTransform.position = currentPos;
            }
            // Check if sprite has moved too far right (ahead of camera)
            else if (currentPos.x - (layerWidth * 0.5f) > cameraX + 15f)
            {
                currentPos.x -= layerWidth;
                layer.layerTransform.position = currentPos;
            }
        }
    }
    
    public void ResetLayers()
    {
        for (int i = 0; i < parallaxLayers.Length; i++)
        {
            if (parallaxLayers[i].layerTransform != null)
            {
                parallaxLayers[i].layerTransform.position = parallaxLayers[i].startPosition;
            }
        }
        
        if (cameraTransform != null)
            lastCameraPosition = cameraTransform.position;
    }
}