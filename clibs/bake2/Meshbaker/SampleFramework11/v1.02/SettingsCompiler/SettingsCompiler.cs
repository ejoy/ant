using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Reflection;
using System.CodeDom.Compiler;
using Microsoft.CSharp;

namespace SettingsCompiler
{
    class SettingsCompiler
    {
        static Assembly CompileSettings(string inputFilePath)
        {
            string fileName = Path.GetFileNameWithoutExtension(inputFilePath);

            string code = File.ReadAllText(inputFilePath);
            code = "using SettingsCompiler;\r\n\r\n" + "namespace " + fileName + "\r\n{\r\n" + code;
            code += "\r\n}";

            Dictionary<string, string> compilerOpts = new Dictionary<string, string> { { "CompilerVersion", "v4.0" } };
            CSharpCodeProvider compiler = new CSharpCodeProvider(compilerOpts);

            string[] sources = { code };
            CompilerParameters compilerParams = new CompilerParameters();
            compilerParams.GenerateInMemory = true;
            compilerParams.ReferencedAssemblies.Add("System.dll");
            compilerParams.ReferencedAssemblies.Add("SettingsCompilerAttributes.dll");
            CompilerResults results = compiler.CompileAssemblyFromSource(compilerParams, sources);
            if(results.Errors.HasErrors)
            {
                string errMsg = "Errors were returned from the C# compiler:\r\n\r\n";
                foreach(CompilerError compilerError in results.Errors)
                {
                    int lineNum = compilerError.Line - 4;
                    errMsg += inputFilePath + "(" + lineNum + "): " + compilerError.ErrorText + "\r\n";
                }
                throw new Exception(errMsg);
            }

            return results.CompiledAssembly;
        }

        static void ReflectType(Type settingsType, List<Setting> settings, List<Type> enumTypes,
                                Dictionary<string, object> constants, string group)
        {
            object settingsInstance = Activator.CreateInstance(settingsType);

            BindingFlags flags = BindingFlags.Instance | BindingFlags.Static | BindingFlags.Public | BindingFlags.NonPublic;
            FieldInfo[] fields = settingsType.GetFields(flags);
            foreach(FieldInfo field in fields)
            {
                foreach(Setting setting in settings)
                    if(setting.Name == field.Name)
                        throw new Exception(string.Format("Duplicate setting \"{0}\" detected", setting.Name));

                if(field.IsLiteral)
                {
                    if (field.FieldType == typeof(float) ||
                        field.FieldType == typeof(int) ||
                        field.FieldType == typeof(uint) ||
                        field.FieldType == typeof(bool))
                    {
                        if (constants.ContainsKey(field.Name))
                            throw new Exception(string.Format("Duplicate constant \"{0}\" detected", field.Name));
                        constants.Add(field.Name, field.GetValue(null));
                    }
                    else
                        throw new Exception(string.Format("Invalid constant type \"{0}\" detected for field {1}", field.FieldType, field.Name));

                    continue;
                }
                else if(field.IsStatic)
                    continue;

                Type fieldType = field.FieldType;
                object fieldValue = field.GetValue(settingsInstance);
                if(fieldType == typeof(float))
                    settings.Add(new FloatSetting((float)fieldValue, field, group));
                else if(fieldType == typeof(int))
                    settings.Add(new IntSetting((int)fieldValue, field, group));
                else if(fieldType == typeof(bool))
                    settings.Add(new BoolSetting((bool)fieldValue, field, group));
                else if(fieldType.IsEnum)
                {
                    if(enumTypes.Contains(fieldType) == false)
                        enumTypes.Add(fieldType);
                    settings.Add(new EnumSetting(fieldValue, field, fieldType, group));
                }
                else if(fieldType == typeof(Direction))
                    settings.Add(new DirectionSetting((Direction)fieldValue, field, group));
                else if(fieldType == typeof(Orientation))
                    settings.Add(new OrientationSetting((Orientation)fieldValue, field, group));
                else if(fieldType == typeof(Color))
                    settings.Add(new ColorSetting((Color)fieldValue, field, group));
                else if(fieldType == typeof(Button))
                    settings.Add(new ButtonSetting(field, group));
                else
                    throw new Exception("Invalid type for setting " + field.Name);
            }
        }

        static void ReflectSettings(Assembly assembly, string inputFilePath, List<Setting> settings, List<Type> enumTypes,
                                    Dictionary<string, object> constants, List<SettingGroup> groups)
        {
            string filePath = Path.GetFileNameWithoutExtension(inputFilePath);
            Type settingsType = assembly.GetType(filePath + ".Settings", false);
            if(settingsType == null)
                throw new Exception("Settings file " + inputFilePath + " doesn't define a \"Settings\" class");

            ReflectType(settingsType, settings, enumTypes, constants, "");

            Type[] nestedTypes = settingsType.GetNestedTypes();
            foreach(Type nestedType in nestedTypes)
            {
                string groupName = DisplayNameAttribute.GetDisplayName(nestedType);
                bool expandGroup = ExpandGroupAttribute.ExpandGroup(nestedType.GetTypeInfo());
                groups.Add(new SettingGroup(groupName, expandGroup));
                ReflectType(nestedType, settings, enumTypes, constants, groupName);
            }
        }

        static void WriteIfChanged(List<string> lines, string outputPath)
        {
            string outputText = "";
            foreach(string line in lines)
                outputText += line + "\r\n";

            string fileText = "";
            if(File.Exists(outputPath))
                fileText = File.ReadAllText(outputPath);

            int idx = fileText.IndexOf("// ================================================================================================");
            if(idx >= 0)
                outputText += "\r\n" + fileText.Substring(idx);

            if(fileText != outputText)
                File.WriteAllText(outputPath, outputText);
        }

        public static void WriteEnumTypes(List<string> lines, List<Type> enumTypes)
        {
            foreach(Type enumType in enumTypes)
            {
                if(enumType.GetEnumUnderlyingType() != typeof(int))
                    throw new Exception("Invalid underlying type for enum " + enumType.Name + ", must be int");
                string[] enumNames = enumType.GetEnumNames();
                int numEnumValues = enumNames.Length;

                Array values = enumType.GetEnumValues();
                int[] enumValues = new int[numEnumValues];
                for(int i = 0; i < numEnumValues; ++i)
                    enumValues[i] = (int)values.GetValue(i);

                lines.Add("enum class " + enumType.Name);
                lines.Add("{");
                for(int i = 0; i < values.Length; ++i)
                    lines.Add("    " + enumNames[i] + " = " + enumValues[i] + ",");
                lines.Add("\r\n    NumValues");

                lines.Add("};\r\n");

                lines.Add("typedef EnumSettingT<" + enumType.Name + "> " + enumType.Name + "Setting;\r\n");
            }
        }

        public static void WriteEnumLabels(List<string> lines, List<Type> enumTypes)
        {
            foreach(Type enumType in enumTypes)
            {
                string[] enumNames = enumType.GetEnumNames();
                int numEnumValues = enumNames.Length;
                string[] enumLabels = new string[numEnumValues];

                for(int i = 0; i < numEnumValues; ++i)
                {
                    FieldInfo enumField = enumType.GetField(enumNames[i]);
                    EnumLabelAttribute attr = enumField.GetCustomAttribute<EnumLabelAttribute>();
                    enumLabels[i] = attr != null ? attr.Label : enumNames[i];
                }

                lines.Add("static const char* " + enumType.Name + "Labels[" + numEnumValues + "] =");
                lines.Add("{");
                foreach(string label in enumLabels)
                    lines.Add("    \"" + label + "\",");

                lines.Add("};\r\n");
            }
        }

        static void GenerateHeader(List<Setting> settings, string outputName, string outputPath,
                                   List<Type> enumTypes, Dictionary<string, object> constants)
        {
            List<string> lines = new List<string>();

            lines.Add("#pragma once");
            lines.Add("");
            lines.Add("#include <PCH.h>");
            lines.Add("#include <Settings.h>");
            lines.Add("#include <Graphics\\GraphicsTypes.h>");
            lines.Add("");
            lines.Add("using namespace SampleFramework11;");
            lines.Add("");

            WriteEnumTypes(lines, enumTypes);

            lines.Add("namespace " + outputName);
            lines.Add("{");

            foreach(KeyValuePair<string, object> constant in constants)
            {
                Type constantType = constant.Value.GetType();
                string typeStr = constantType.ToString();
                string valueStr = constant.Value.ToString();
                if(constantType == typeof(uint))
                    typeStr = "uint64";
                else if(constantType == typeof(int))
                    typeStr = "int64";
                else if(constantType == typeof(bool))
                {
                    typeStr = "bool";
                    valueStr = valueStr.ToLower();
                }
                else if(constantType == typeof(float))
                {
                    typeStr = "float";
                    valueStr = FloatSetting.FloatString((float)constant.Value);
                }
                lines.Add(string.Format("    static const {0} {1} = {2};", typeStr, constant.Key, valueStr));
            }

            lines.Add("");

            uint numCBSettings = 0;
            foreach(Setting setting in settings)
            {
                setting.WriteDeclaration(lines);
                if(setting.UseAsShaderConstant)
                    ++numCBSettings;
            }

            if(numCBSettings > 0)
            {
                lines.Add("");
                lines.Add(string.Format("    struct {0}CBuffer",  outputName));
                lines.Add("    {");

                uint cbSize = 0;
                foreach(Setting setting in settings)
                    setting.WriteCBufferStruct(lines, ref cbSize);

                lines.Add("    };");
                lines.Add("");
                lines.Add(string.Format("    extern ConstantBuffer<{0}CBuffer> CBuffer;", outputName));
            }

            lines.Add("");
            lines.Add("    void Initialize(ID3D11Device* device);");
            lines.Add("    void Update();");
            lines.Add("    void UpdateCBuffer(ID3D11DeviceContext* context);");

            lines.Add("};");

            WriteIfChanged(lines, outputPath);
        }

        static void GenerateCPP(List<Setting> settings, string outputName, string outputPath,
                                List<Type> enumTypes, List<SettingGroup> groups)
        {
            List<string> lines = new List<string>();

            lines.Add("#include <PCH.h>");
            lines.Add("#include <TwHelper.h>");
            lines.Add("#include \"" + outputName + ".h\"");
            lines.Add("");
            lines.Add("using namespace SampleFramework11;");
            lines.Add("");

            WriteEnumLabels(lines, enumTypes);

            lines.Add("namespace " + outputName);
            lines.Add("{");

            uint numCBSettings = 0;
            foreach(Setting setting in settings)
            {
                setting.WriteDefinition(lines);
                if(setting.UseAsShaderConstant)
                    ++numCBSettings;
            }

            if(numCBSettings > 0)
            {
                lines.Add("");
                lines.Add(string.Format("    ConstantBuffer<{0}CBuffer> CBuffer;", outputName));
            }

            lines.Add("");
            lines.Add("    void Initialize(ID3D11Device* device)");
            lines.Add("    {");
            lines.Add("        TwBar* tweakBar = Settings.TweakBar();");
            lines.Add("");

            foreach(Setting setting in settings)
            {
                setting.WriteInitialization(lines);
                setting.WritePostInitialization(lines);
            }

            foreach(SettingGroup group in groups)
            {
                lines.Add(string.Format("        TwHelper::SetOpened(tweakBar, \"{0}\", {1});", group.Name, group.Expand ? "true" : "false"));
                lines.Add("");
            }

            if(numCBSettings > 0)
                lines.Add("        CBuffer.Initialize(device);");

            lines.Add("    }");

            lines.Add("");
            lines.Add("    void Update()");
            lines.Add("    {");

            foreach(Setting setting in settings)
                setting.WriteVirtualCode(lines);

            lines.Add("    }");

            lines.Add("");
            lines.Add("    void UpdateCBuffer(ID3D11DeviceContext* context)");
            lines.Add("    {");

            foreach(Setting setting in settings)
                setting.WriteCBufferUpdate(lines);

            if(numCBSettings > 0)
            {
                lines.Add("");
                lines.Add("        CBuffer.ApplyChanges(context);");
                lines.Add("        CBuffer.SetVS(context, 7);");
                lines.Add("        CBuffer.SetHS(context, 7);");
                lines.Add("        CBuffer.SetDS(context, 7);");
                lines.Add("        CBuffer.SetGS(context, 7);");
                lines.Add("        CBuffer.SetPS(context, 7);");
                lines.Add("        CBuffer.SetCS(context, 7);");
            }

            lines.Add("    }");

            lines.Add("}");

            WriteIfChanged(lines, outputPath);
        }

        static void GenerateHLSL(List<Setting> settings, string outputName, string outputPath,
                                 List<Type> enumTypes, Dictionary<string, object> constants)
        {
            uint numCBSettings = 0;
            foreach(Setting setting in settings)
            {
                if(setting.UseAsShaderConstant)
                    ++numCBSettings;
            }

            List<string> lines = new List<string>();

            if(numCBSettings == 0)
                WriteIfChanged(lines, outputPath);

            lines.Add(string.Format("cbuffer {0} : register(b7)", outputName));
            lines.Add("{");

            foreach(Setting setting in settings)
                setting.WriteHLSL(lines);

            lines.Add("}");
            lines.Add("");

            foreach(Type enumType in enumTypes)
            {
                string[] enumNames = enumType.GetEnumNames();
                Array enumValues = enumType.GetEnumValues();
                for(int i = 0; i < enumNames.Length; ++i)
                {
                    string line = "static const int " + enumType.Name + "_";
                    line += enumNames[i] + " = " + (int)enumValues.GetValue(i) + ";";
                    lines.Add(line);
                }

                lines.Add("");
            }

            foreach(KeyValuePair<string, object> constant in constants)
            {
                Type constantType = constant.Value.GetType();
                string typeStr = constantType.ToString();
                string valueStr = constant.Value.ToString();
                if(constantType == typeof(uint))
                    typeStr = "uint";
                else if(constantType == typeof(int))
                    typeStr = "int";
                else if(constantType == typeof(bool))
                {
                    typeStr = "bool";
                    valueStr = valueStr.ToLower();
                }
                else if(constantType == typeof(float))
                {
                    typeStr = "float";
                    valueStr = FloatSetting.FloatString((float)constant.Value);
                }
                lines.Add(string.Format("static const {0} {1} = {2};", typeStr, constant.Key, valueStr));
            }

            WriteIfChanged(lines, outputPath);
        }

        static void Run(string[] args)
        {
            if(args.Length < 1)
                throw new Exception("Invalid command-line parameters");

            List<Setting> settings = new List<Setting>();
            List<Type> enumTypes = new List<Type>();
            Dictionary<string, object> constants = new Dictionary<string, object>();
            List<SettingGroup> groups = new List<SettingGroup>();

            string filePath = args[0];
            string fileName = Path.GetFileNameWithoutExtension(filePath);

            Assembly compiledAssembly = CompileSettings(filePath);
            ReflectSettings(compiledAssembly, filePath, settings, enumTypes, constants, groups);

            string outputDir = Path.GetDirectoryName(filePath);
            string outputPath = Path.Combine(outputDir, fileName) + ".h";
            GenerateHeader(settings, fileName, outputPath, enumTypes, constants);

            outputPath = Path.Combine(outputDir, fileName) + ".cpp";
            GenerateCPP(settings, fileName, outputPath, enumTypes, groups);

            outputPath = Path.Combine(outputDir, fileName) + ".hlsl";
            GenerateHLSL(settings, fileName, outputPath, enumTypes, constants);

            // Generate a dummy file that MSBuild can use to track dependencies
            outputPath = Path.Combine(outputDir, fileName) + ".deps";
            File.WriteAllText(outputPath, "This file is output to allow MSBuild to track dependencies");
        }

        static int Main(string[] args)
        {

            if(Debugger.IsAttached)
            {
                Run(args);
            }
            else
            {
                try
                {
                    Run(args);
                }
                catch(Exception e)
                {
                    Console.WriteLine("An error ocurred during settings compilation:\n\n" + e.Message);
                    return 1;
                }
            }

            return 0;
        }
    }
}