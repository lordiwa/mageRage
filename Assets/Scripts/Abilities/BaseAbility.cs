using UnityEngine;

[CreateAssetMenu(fileName = "New Ability", menuName = "MAGE RAGE/Ability")]
public class BaseAbility : ScriptableObject
{
    [Header("Ability Info")]
    public string abilityName = "New Ability";
    public string description = "Ability description";
    public Sprite icon;
    
    [Header("Costs & Cooldowns")]
    public float manaCost = 10f;
    public float cooldownDuration = 2f;
    
    [Header("Ability Settings")]
    public GameObject effectPrefab; // Projectile, effect, etc.
    public float damage = 25f;
    public float speed = 10f;
    public float lifetime = 3f;
    
    // Override this in specific ability types
    public virtual void Activate(Vector3 casterPosition, Vector2 direction, Transform caster)
    {
        // Spawn projectile if assigned
        if (effectPrefab != null)
        {
            GameObject projectileObj = Instantiate(effectPrefab, casterPosition, Quaternion.identity);
            
            // Try to initialize as projectile
            Projectile projectile = projectileObj.GetComponent<Projectile>();
            if (projectile != null)
            {
                projectile.Initialize(direction, speed, damage, lifetime);
            }
            else
            {
                // Fallback for non-projectile effects
                Rigidbody2D rb = projectileObj.GetComponent<Rigidbody2D>();
                if (rb != null)
                {
                    rb.linearVelocity = direction.normalized * speed;
                }
                
                // Destroy after lifetime
                Destroy(projectileObj, lifetime);
            }
        }
        
        Debug.Log($"Activated {abilityName} for {manaCost} mana!");
    }
    
    public virtual bool CanActivate(ManaSystem manaSystem)
    {
        return manaSystem.CurrentMana >= manaCost;
    }
}