#if UNITY_EDITOR

using System;
using System.Reflection;
using UnityEditor;
using UnityEngine;

// Add this to use Windows Forms for screen info
#if UNITY_EDITOR_WIN
using WinForms = System.Windows.Forms;
#endif
/// <summary>
/// Utility for opening the Game view fullscreen on a specific monitor.
/// </summary>
public static class FullscreenGameView
{
    static readonly Type GameViewType = Type.GetType("UnityEditor.GameView,UnityEditor");
    static readonly PropertyInfo ShowToolbarProperty = GameViewType?.GetProperty("showToolbar", BindingFlags.Instance | BindingFlags.NonPublic);
    static readonly object False = false; // Box once.

    static EditorWindow instance;

    [MenuItem("Window/General/Game (Fullscreen) %G", priority = 2)]
    public static void Toggle()
    {
        if (GameViewType == null)
        {
            Debug.LogError("GameView type not found.");
            return;
        }

        if (ShowToolbarProperty == null)
        {
            Debug.LogWarning("GameView.showToolbar property not found.");
        }

        if (instance != null)
        {
            instance.Close();
            instance = null;
        }
        else
        {
            instance = (EditorWindow)ScriptableObject.CreateInstance(GameViewType);

            ShowToolbarProperty?.SetValue(instance, False);

            Rect fullscreenRect;

            // Use System.Windows.Forms to find all screens
            var screens = WinForms.Screen.AllScreens;
            if (screens.Length > 1)
            {
                // Use the second monitor (index 1)
                var bounds = screens[1].Bounds;
                fullscreenRect = new Rect(bounds.X, bounds.Y, bounds.Width, bounds.Height);
                Debug.Log($"Opening fullscreen Game view on second monitor: {bounds}");
            }
            else
            {
                // Fall back to main monitor
                var res = UnityEngine.Screen.currentResolution;
                fullscreenRect = new Rect(0, 0, res.width, res.height);
                Debug.LogWarning("Only one monitor detected — opening fullscreen on primary monitor.");
            }

            instance.ShowPopup();
            instance.position = fullscreenRect;
            instance.Focus();
        }
    }
}

#endif
