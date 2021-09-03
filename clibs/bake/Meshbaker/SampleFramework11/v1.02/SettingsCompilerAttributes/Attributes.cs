using System;
using System.Reflection;

namespace SettingsCompiler
{
    public struct Direction
    {
        public float X;
        public float Y;
        public float Z;

        public Direction(float x, float y, float z)
        {
            X = x;
            Y = y;
            Z = z;
        }
    }

    public struct Color
    {
        public float R;
        public float G;
        public float B;

        public Color(float r, float g, float b)
        {
            R = r;
            G = g;
            B = b;
        }

        public Color(float r, float g, float b, float intensity)
        {
            R = r * intensity;
            G = g * intensity;
            B = b * intensity;
        }
    }

    public struct Orientation
    {
        public float X;
        public float Y;
        public float Z;
        public float W;

        public static Orientation Identity = new Orientation(0.0f, 0.0f, 0.0f, 1.0f);

        public Orientation(float x, float y, float z, float w)
        {
            X = x;
            Y = y;
            Z = z;
            W = w;
        }
    }

    public struct Button
    {
    }

    public enum ConversionMode
    {
        None = 0,
        Square = 1,
        SquareRoot = 2,
        DegToRadians = 3,
    }

    public enum ColorUnit
    {
        None = 0,
        Luminance,
        Illuminance,
        LuminousPower,
        EV100
    }

    [AttributeUsage(AttributeTargets.Field | AttributeTargets.Class, Inherited = false, AllowMultiple = false)]
    public class DisplayNameAttribute : Attribute
    {
        public readonly string DisplayName;

        public DisplayNameAttribute(string displayName)
        {
            this.DisplayName = displayName;
        }

        public static string MakeFriendlyName(string settingName)
        {
            string newName = settingName;
            char[] characters = settingName.ToCharArray();
            for(int i = characters.Length - 2; i >= 0; --i)
            {
                if(char.IsLower(characters[i]) && char.IsUpper(characters[i + 1]))
                    newName = newName.Insert(i + 1, " ");
            }

            return newName;
        }

        public static void GetDisplayName(FieldInfo field, ref string displayName)
        {
            DisplayNameAttribute attr = field.GetCustomAttribute<DisplayNameAttribute>();
            if(attr != null)
                displayName = attr.DisplayName;
            else
                displayName = MakeFriendlyName(field.Name);
        }

        public static string GetDisplayName(Type classType)
        {
            DisplayNameAttribute attr = classType.GetCustomAttribute<DisplayNameAttribute>();
            if(attr != null)
                return attr.DisplayName;
            else
                return MakeFriendlyName(classType.Name);
        }
    }

    [AttributeUsage(AttributeTargets.Field | AttributeTargets.Class, Inherited = false, AllowMultiple = false)]
    public class HelpTextAttribute : Attribute
    {
        public readonly string HelpText;

        public HelpTextAttribute(string helpText)
        {
            this.HelpText = helpText;
        }

        public static void GetHelpText(FieldInfo field, ref string helpText)
        {
            HelpTextAttribute attr = field.GetCustomAttribute<HelpTextAttribute>();
            if(attr != null)
                helpText = attr.HelpText;
        }
    }

    [AttributeUsage(AttributeTargets.Field, Inherited = false, AllowMultiple = false)]
    public class GroupAttribute : Attribute
    {
        public readonly string Group;

        public GroupAttribute(string group)
        {
            this.Group = group;
        }

        public static void GetGroup(FieldInfo field, ref string group)
        {
            GroupAttribute attr = field.GetCustomAttribute<GroupAttribute>();
            if(attr != null)
                group = attr.Group;
        }
    }

    [AttributeUsage(AttributeTargets.Field, Inherited = false, AllowMultiple = false)]
    public class MinValueAttribute : Attribute
    {
        public readonly float MinValueFloat;
        public readonly int MinValueInt;

        public MinValueAttribute(float minValue)
        {
            this.MinValueFloat = minValue;
            this.MinValueInt = (int)minValue;
        }

        public MinValueAttribute(int minValue)
        {
            this.MinValueFloat = (float)minValue;
            this.MinValueInt = minValue;
        }

        public static void GetMinValue(FieldInfo field, ref float minValue)
        {
            MinValueAttribute attr = field.GetCustomAttribute<MinValueAttribute>();
            if(attr != null)
                minValue = attr.MinValueFloat;
        }

        public static void GetMinValue(FieldInfo field, ref int minValue)
        {
            MinValueAttribute attr = field.GetCustomAttribute<MinValueAttribute>();
            if(attr != null)
                minValue = attr.MinValueInt;
        }
    }

    [AttributeUsage(AttributeTargets.Field, Inherited = false, AllowMultiple = false)]
    public class MaxValueAttribute : Attribute
    {
        public readonly float MaxValueFloat;
        public readonly int MaxValueInt;

        public MaxValueAttribute(float maxValue)
        {
            this.MaxValueFloat = maxValue;
            this.MaxValueInt = (int)maxValue;
        }

        public MaxValueAttribute(int maxValue)
        {
            this.MaxValueFloat = (float)maxValue;
            this.MaxValueInt = maxValue;
        }

        public static void GetMaxValue(FieldInfo field, ref float maxValue)
        {
            MaxValueAttribute attr = field.GetCustomAttribute<MaxValueAttribute>();
            if(attr != null)
                maxValue = attr.MaxValueFloat;
        }

        public static void GetMaxValue(FieldInfo field, ref int maxValue)
        {
            MaxValueAttribute attr = field.GetCustomAttribute<MaxValueAttribute>();
            if(attr != null)
                maxValue = attr.MaxValueInt;
        }
    }

    [AttributeUsage(AttributeTargets.Field, Inherited = false, AllowMultiple = false)]
    public class StepSizeAttribute : System.Attribute
    {
        public readonly float StepSizeFloat;
        public readonly int StepSizeInt;

        public StepSizeAttribute(float stepSize)
        {
            this.StepSizeFloat = stepSize;
            this.StepSizeInt = (int)stepSize;
        }

        public StepSizeAttribute(int stepSize)
        {
            this.StepSizeFloat = (float)stepSize;
            this.StepSizeInt = stepSize;
        }

        public static void GetStepSize(FieldInfo field, ref float stepSize)
        {
            StepSizeAttribute attr = field.GetCustomAttribute<StepSizeAttribute>();
            if(attr != null)
                stepSize = attr.StepSizeFloat;
        }

        public static void GetStepSize(FieldInfo field, ref int stepSize)
        {
            StepSizeAttribute attr = field.GetCustomAttribute<StepSizeAttribute>();
            if(attr != null)
                stepSize = attr.StepSizeInt;
        }
    }

    [AttributeUsage(AttributeTargets.Field, Inherited = false, AllowMultiple = false)]
    public class EnumLabelAttribute : System.Attribute
    {
        public readonly string Label;
        public EnumLabelAttribute(string label)
        {
            Label = label;
        }
    }

    [AttributeUsage(AttributeTargets.Field | AttributeTargets.Class, Inherited = false, AllowMultiple = false)]
    public class UseAsShaderConstantAttribute : Attribute
    {
        public readonly bool UseAsShaderConstant = true;

        public UseAsShaderConstantAttribute(bool useAsShaderConstant)
        {
            this.UseAsShaderConstant = useAsShaderConstant;
        }

        public static bool UseFieldAsShaderConstant(FieldInfo field)
        {
            UseAsShaderConstantAttribute attr = field.GetCustomAttribute<UseAsShaderConstantAttribute>();
            if(attr != null)
                return attr.UseAsShaderConstant;
            else
                return true;
        }
    }

    [AttributeUsage(AttributeTargets.Field | AttributeTargets.Class, Inherited = false, AllowMultiple = false)]
    public class HDRAttribute : Attribute
    {
        public readonly bool HDR = false;

        public HDRAttribute(bool hdr)
        {
            this.HDR = hdr;
        }

        public static bool HDRColor(FieldInfo field)
        {
            HDRAttribute attr = field.GetCustomAttribute<HDRAttribute>();
            if(attr != null)
                return attr.HDR;
            else
                return false;
        }
    }

    [AttributeUsage(AttributeTargets.Field, Inherited = false, AllowMultiple = false)]
    public class ConversionModeAttribute : Attribute
    {
        public readonly ConversionMode Mode;

        public ConversionModeAttribute(ConversionMode mode)
        {
            this.Mode = mode;
        }

        public static ConversionMode GetConversionMode(FieldInfo field)
        {
            ConversionModeAttribute attr = field.GetCustomAttribute<ConversionModeAttribute>();
            if(attr != null)
                return attr.Mode;
            else
                return ConversionMode.None;
        }
    }

    [AttributeUsage(AttributeTargets.Field, Inherited = false, AllowMultiple = false)]
    public class ConversionScaleAttribute : System.Attribute
    {
        public readonly float ConversionScale;

        public ConversionScaleAttribute(float scale)
        {
            this.ConversionScale = scale;
        }


        public static float GetConversionScale(FieldInfo field)
        {
            ConversionScaleAttribute attr = field.GetCustomAttribute<ConversionScaleAttribute>();
            if(attr != null)
                return attr.ConversionScale;
            else
                return 1.0f;
        }
    }

    [AttributeUsage(AttributeTargets.Class, Inherited = false, AllowMultiple = false)]
    public class ExpandGroupAttribute : Attribute
    {
        public readonly bool Expand = true;

        public ExpandGroupAttribute(bool expand)
        {
            this.Expand = expand;
        }

        public static bool ExpandGroup(TypeInfo typeInfo)
        {
            ExpandGroupAttribute attr = typeInfo.GetCustomAttribute<ExpandGroupAttribute>();
            if(attr != null)
                return attr.Expand;
            else
                return true;
        }
    }

    [AttributeUsage(AttributeTargets.Field, Inherited = false, AllowMultiple = false)]
    public class ColorUnitAttribute : Attribute
    {
        public readonly ColorUnit Unit;

        public ColorUnitAttribute(ColorUnit unit)
        {
            this.Unit = unit;
        }

        public static ColorUnit GetColorUnit(FieldInfo field)
        {
            ColorUnitAttribute attr = field.GetCustomAttribute<ColorUnitAttribute>();
            if(attr != null)
                return attr.Unit;
            else
                return ColorUnit.None;
        }
    }

    [AttributeUsage(AttributeTargets.Field, Inherited = false, AllowMultiple = false)]
    public class VisibleAttribute : Attribute
    {
        public readonly bool Visible = true;

        public VisibleAttribute(bool visible)
        {
            this.Visible = visible;
        }

        public static bool IsVisible(FieldInfo field)
        {
            VisibleAttribute attr = field.GetCustomAttribute<VisibleAttribute>();
            if(attr != null)
                return attr.Visible;
            else
                return true;
        }
    }

    [AttributeUsage(AttributeTargets.Field, Inherited = false, AllowMultiple = false)]
    public class EditableAttribute : Attribute
    {
        public readonly bool Editable = true;

        public EditableAttribute(bool editable)
        {
            this.Editable = editable;
        }

        public static bool IsEditable(FieldInfo field)
        {
            EditableAttribute attr = field.GetCustomAttribute<EditableAttribute>();
            if(attr != null)
                return attr.Editable;
            else
                return true;
        }
    }

    [AttributeUsage(AttributeTargets.Field, Inherited = false, AllowMultiple = false)]
    public class VirtualSettingAttribute : Attribute
    {
        public readonly string Code;

        public VirtualSettingAttribute(string code)
        {
            this.Code = code;
        }

        public static string VirtualSettingCode(FieldInfo field)
        {
            VirtualSettingAttribute attr = field.GetCustomAttribute<VirtualSettingAttribute>();
            if(attr != null)
                return attr.Code;
            else
                return null;
        }
    }
}