using UnityEngine;
using UnityEngine.InputSystem;

[RequireComponent(typeof(Rigidbody2D))]
public class PlayerController : MonoBehaviour
{
    [Header("Movement Settings")]
    [SerializeField] private float moveSpeed = 8f;
    [SerializeField] private float acceleration = 20f;
    [SerializeField] private float deceleration = 15f;
    
    [Header("Boundaries")]
    [SerializeField] private float leftBoundary = -10f;
    [SerializeField] private float rightBoundary = 10f;
    [SerializeField] private float topBoundary = 5f;
    [SerializeField] private float bottomBoundary = -5f;
    
    [Header("Abilities")]
    [SerializeField] private BaseAbility[] abilities = new BaseAbility[6];
    [SerializeField] private float[] abilityCooldowns = new float[6];
    
    // Components
    private Rigidbody2D rb;
    private PlayerInput playerInput;
    private ManaSystem manaSystem;
    
    // Input
    private Vector2 moveInput;
    private Vector2 currentVelocity;
    
    // Actions (will be set from Input System)
    private InputAction moveAction;
    private InputAction[] abilityActions = new InputAction[6];
    
    void Awake()
    {
        rb = GetComponent<Rigidbody2D>();
        playerInput = GetComponent<PlayerInput>();
        
        // Try to get ManaSystem component - might not exist yet
        manaSystem = GetComponent<ManaSystem>();
        if (manaSystem == null)
        {
            Debug.LogWarning("ManaSystem component not found on Player. Add it manually or some abilities won't work.");
        }
        
        // Get the move action from Input System
        moveAction = playerInput.actions["Move"];
        
        // Get ability actions with error checking
        for (int i = 0; i < 6; i++)
        {
            string actionName = $"Ability{i + 1}";
            var action = playerInput.actions.FindAction(actionName);
            if (action != null)
            {
                abilityActions[i] = action;
            }
            else
            {
                Debug.LogWarning($"Action '{actionName}' not found in Input Actions!");
            }
        }
    }
    
    void OnEnable()
    {
        moveAction.Enable();
    }
    
    void OnDisable()
    {
        moveAction.Disable();
    }
    
    void Update()
    {
        HandleInput();
        HandleAbilities();
        UpdateCooldowns();
        
        // Debug all joystick buttons
        for (int i = 0; i < 10; i++)
        {
            if (Input.GetKeyDown($"joystick button {i}"))
            {
                Debug.Log($"Physical joystick button {i} pressed!");
            }
        }
    }
    
    void FixedUpdate()
    {
        HandleMovement();
        ConstrainToBoundaries();
    }
    
    void HandleInput()
    {
        moveInput = moveAction.ReadValue<Vector2>();
    }
    
    void HandleAbilities()
    {
        for (int i = 0; i < abilityActions.Length; i++)
        {
            if (abilityActions[i] != null && abilityActions[i].WasPressedThisFrame())
            {
                Debug.Log($"Button {i+1} pressed!");
                TryUseAbility(i);
            }
        }
    }
    
    void TryUseAbility(int abilityIndex)
    {
        Debug.Log($"TryUseAbility called for index {abilityIndex}");
        
        // Check if we have mana system
        if (manaSystem == null)
        {
            Debug.LogWarning("No ManaSystem found - cannot use abilities!");
            return;
        }
        
        Debug.Log($"ManaSystem found, checking ability...");
        
        // Check if ability exists and is off cooldown
        if (abilities[abilityIndex] == null || abilityCooldowns[abilityIndex] > 0)
        {
            Debug.Log($"Ability check failed - ability null: {abilities[abilityIndex] == null}, cooldown: {abilityCooldowns[abilityIndex]}");
            return;
        }
            
        BaseAbility ability = abilities[abilityIndex];
        Debug.Log($"Found ability: {ability.abilityName}");
        
        // Check if we have enough mana
        if (!ability.CanActivate(manaSystem))
        {
            Debug.Log($"Not enough mana for {ability.abilityName}!");
            return;
        }
        
        Debug.Log($"All checks passed, activating {ability.abilityName}!");
        
        // Always shoot forward (right) in sidescroller - FIXED LINE
        Vector2 direction = Vector2.right;
        ability.Activate(transform.position, direction, transform);
        
        // Spend mana and start cooldown
        manaSystem.SpendMana(ability.manaCost);
        abilityCooldowns[abilityIndex] = ability.cooldownDuration;
    }
    
    void UpdateCooldowns()
    {
        for (int i = 0; i < abilityCooldowns.Length; i++)
        {
            if (abilityCooldowns[i] > 0)
            {
                abilityCooldowns[i] -= Time.deltaTime;
            }
        }
    }
    
    void HandleMovement()
    {
        Vector2 targetVelocity = moveInput * moveSpeed;
        
        // Smooth acceleration/deceleration
        float accelRate = (moveInput.magnitude > 0) ? acceleration : deceleration;
        
        currentVelocity = Vector2.MoveTowards(currentVelocity, targetVelocity, 
                                            accelRate * Time.fixedDeltaTime);
        
        rb.linearVelocity = currentVelocity;
    }
    
    void ConstrainToBoundaries()
    {
        Vector3 pos = transform.position;
        pos.x = Mathf.Clamp(pos.x, leftBoundary, rightBoundary);
        pos.y = Mathf.Clamp(pos.y, bottomBoundary, topBoundary);
        transform.position = pos;
    }
    
    // Visual debugging in Scene view
    void OnDrawGizmosSelected()
    {
        Gizmos.color = Color.yellow;
        Vector3 topLeft = new Vector3(leftBoundary, topBoundary, 0);
        Vector3 topRight = new Vector3(rightBoundary, topBoundary, 0);
        Vector3 bottomLeft = new Vector3(leftBoundary, bottomBoundary, 0);
        Vector3 bottomRight = new Vector3(rightBoundary, bottomBoundary, 0);
        
        Gizmos.DrawLine(topLeft, topRight);
        Gizmos.DrawLine(topRight, bottomRight);
        Gizmos.DrawLine(bottomRight, bottomLeft);
        Gizmos.DrawLine(bottomLeft, topLeft);
    }
}