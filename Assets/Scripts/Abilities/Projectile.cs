using UnityEngine;

[RequireComponent(typeof(Rigidbody2D), typeof(Collider2D))]
public class Projectile : MonoBehaviour
{
    [Header("Projectile Settings")]
    [SerializeField] private float damage = 25f;
    [SerializeField] private float speed = 10f;
    [SerializeField] private float lifetime = 3f;
    [SerializeField] private bool piercing = false;
    [SerializeField] private int maxHits = 1;
    
    [Header("Effects")]
    [SerializeField] private GameObject hitEffect;
    [SerializeField] private GameObject trailEffect;
    
    private Rigidbody2D rb;
    private Vector2 direction;
    private int currentHits = 0;
    private bool isInitialized = false;
    
    void Awake()
    {
        rb = GetComponent<Rigidbody2D>();
        
        // Set up physics
        rb.gravityScale = 0; // No gravity for magic projectiles
        GetComponent<Collider2D>().isTrigger = true; // Trigger for hit detection
    }
    
    void Start()
    {
        // Auto-destroy after lifetime
        Destroy(gameObject, lifetime);
        
        // Spawn trail effect if assigned
        if (trailEffect != null)
        {
            GameObject trail = Instantiate(trailEffect, transform);
        }
    }
    
    public void Initialize(Vector2 moveDirection, float projectileSpeed, float projectileDamage, float projectileLifetime)
    {
        direction = moveDirection.normalized;
        speed = projectileSpeed;
        damage = projectileDamage;
        lifetime = projectileLifetime;
        isInitialized = true;
        
        // Set velocity
        rb.linearVelocity = direction * speed;
        
        // Rotate to face movement direction
        float angle = Mathf.Atan2(direction.y, direction.x) * Mathf.Rad2Deg;
        transform.rotation = Quaternion.AngleAxis(angle, Vector3.forward);
    }
    
    void FixedUpdate()
    {
        // Ensure consistent velocity (in case of collisions)
        if (isInitialized && rb.linearVelocity.magnitude < speed * 0.9f)
        {
            rb.linearVelocity = direction * speed;
        }
    }
    
    void Update()
    {
        // Auto-destroy if off screen
        Vector3 screenPos = Camera.main.WorldToScreenPoint(transform.position);
        if (screenPos.x < -50 || screenPos.x > Screen.width + 50 || 
            screenPos.y < -50 || screenPos.y > Screen.height + 50)
        {
            Destroy(gameObject);
        }
    }

    void OnTriggerEnter2D(Collider2D other)
    {
        // Check if we hit an enemy (you'll add enemy tag later)
        if (other.CompareTag("Enemy"))
        {
            HitTarget(other.gameObject);
        }
        
        // Check if we hit environment (walls, etc.)
        if (other.CompareTag("Wall") || other.CompareTag("Environment"))
        {
            HitEnvironment();
        }
    }
    
    void HitTarget(GameObject target)
    {
        currentHits++;
        
        // Apply damage (you'll implement this when you add enemies)
        // Enemy enemy = target.GetComponent<Enemy>();
        // if (enemy != null) enemy.TakeDamage(damage);
        
        Debug.Log($"Projectile hit {target.name} for {damage} damage!");
        
        // Spawn hit effect
        if (hitEffect != null)
        {
            Instantiate(hitEffect, transform.position, transform.rotation);
        }
        
        // Destroy if not piercing or max hits reached
        if (!piercing || currentHits >= maxHits)
        {
            DestroyProjectile();
        }
    }
    
    void HitEnvironment()
    {
        // Spawn hit effect
        if (hitEffect != null)
        {
            Instantiate(hitEffect, transform.position, transform.rotation);
        }
        
        DestroyProjectile();
    }
    
    void DestroyProjectile()
    {
        // Add any destruction effects here
        Destroy(gameObject);
    }
    
    // For debugging - draw the projectile's path
    void OnDrawGizmos()
    {
        if (isInitialized)
        {
            Gizmos.color = Color.red;
            Gizmos.DrawRay(transform.position, direction * 2f);
        }
    }
}