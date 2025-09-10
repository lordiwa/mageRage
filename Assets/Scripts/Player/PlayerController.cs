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
    
    // Public accessors for external systems
    public BaseAbility[] Abilities => abilities;
    public float[] AbilityCooldowns => abilityCooldowns;
    
    // Components
    private Rigidbody2D rb;
    private PlayerInput playerInput;
    private ManaSystem manaSystem;
    
    // Input
    private Vector2 moveInput;
    private Vector2 currentVelocity;
    
    // Actions
    private InputAction moveAction;
    private InputAction[] abilityActions = new InputAction[6];
    
    void Awake()
    {
        rb = GetComponent<Rigidbody2D>();
        playerInput = GetComponent<PlayerInput>();
        
        manaSystem = GetComponent<ManaSystem>();
        if (manaSystem == null)
        {
            Debug.LogWarning("ManaSystem component not found on Player.");
        }
        
        moveAction = playerInput.actions["Move"];
        
        for (int i = 0; i < 6; i++)
        {
            string actionName = $"Ability{i + 1}";
            var action = playerInput.actions.FindAction(actionName);
            if (action != null)
            {
                abilityActions[i] = action;
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
                TryUseAbility(i);
            }
        }
    }
    
    bool TryUseAbility(int abilityIndex)
    {
        if (manaSystem == null) return false;
        
        if (abilities[abilityIndex] == null || abilityCooldowns[abilityIndex] > 0)
            return false;
            
        BaseAbility ability = abilities[abilityIndex];
        
        if (!ability.CanActivate(manaSystem))
            return false;
        
        Vector2 direction = Vector2.right;
        ability.Activate(transform.position, direction, transform);
        
        manaSystem.SpendMana(ability.manaCost);
        abilityCooldowns[abilityIndex] = ability.cooldownDuration;
        
        return true;
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