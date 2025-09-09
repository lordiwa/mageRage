using UnityEngine;
using UnityEngine.Events;

public class ManaSystem : MonoBehaviour
{
    [Header("Mana Settings")]
    [SerializeField] private float maxMana = 100f;
    [SerializeField] private float manaRegenRate = 20f; // Mana per second
    [SerializeField] private float manaRegenDelay = 1f; // Delay after spending mana
    
    [Header("Current State")]
    [SerializeField] private float currentMana;
    [SerializeField] private bool isRegenerating = true;
    
    // Events for UI updates
    public UnityEvent<float, float> OnManaChanged; // current, max
    public UnityEvent<bool> OnManaAvailable; // true when mana > 0
    
    private float lastManaUseTime;
    
    public float CurrentMana => currentMana;
    public float MaxMana => maxMana;
    public float ManaPercentage => currentMana / maxMana;
    public bool HasMana => currentMana > 0;
    
    void Start()
    {
        currentMana = maxMana;
        OnManaChanged?.Invoke(currentMana, maxMana);
    }
    
    void Update()
    {
        HandleManaRegeneration();
    }
    
    void HandleManaRegeneration()
    {
        // Check if we should start regenerating
        if (!isRegenerating && Time.time - lastManaUseTime >= manaRegenDelay)
        {
            isRegenerating = true;
        }
        
        // Regenerate mana
        if (isRegenerating && currentMana < maxMana)
        {
            float previousMana = currentMana;
            currentMana = Mathf.Min(currentMana + manaRegenRate * Time.deltaTime, maxMana);
            
            // Fire events if mana changed
            if (currentMana != previousMana)
            {
                OnManaChanged?.Invoke(currentMana, maxMana);
                
                // Fire mana available event when crossing from 0
                if (previousMana <= 0 && currentMana > 0)
                {
                    OnManaAvailable?.Invoke(true);
                }
            }
        }
    }
    
    public bool TrySpendMana(float amount)
    {
        if (currentMana >= amount)
        {
            SpendMana(amount);
            return true;
        }
        return false;
    }
    
    public void SpendMana(float amount)
    {
        float previousMana = currentMana;
        currentMana = Mathf.Max(currentMana - amount, 0);
        
        // Stop regeneration and reset timer
        isRegenerating = false;
        lastManaUseTime = Time.time;
        
        // Fire events
        OnManaChanged?.Invoke(currentMana, maxMana);
        
        // Fire mana depleted event when crossing to 0
        if (previousMana > 0 && currentMana <= 0)
        {
            OnManaAvailable?.Invoke(false);
        }
    }
    
    public void RestoreMana(float amount)
    {
        float previousMana = currentMana;
        currentMana = Mathf.Min(currentMana + amount, maxMana);
        
        OnManaChanged?.Invoke(currentMana, maxMana);
        
        // Fire mana available event when crossing from 0
        if (previousMana <= 0 && currentMana > 0)
        {
            OnManaAvailable?.Invoke(true);
        }
    }
    
    // Debug info
    void OnGUI()
    {
        if (Application.isPlaying)
        {
            GUI.Label(new Rect(10, 10, 200, 20), $"Mana: {currentMana:F1} / {maxMana:F1}");
            GUI.Label(new Rect(10, 30, 200, 20), $"Regenerating: {isRegenerating}");
        }
    }
}