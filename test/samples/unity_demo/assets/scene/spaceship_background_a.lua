local World = {
 { Scene ="Assets/spaceship_background_a.unity",
   Ent = {
    {Name = "Spaceship_Background_A",
     Lod = 1,
     Pos={0.000,0.000,0.000},Rot={270.000,0.000,0.000},Scl={1.000,1.000,1.000},
     Ent = {
      {Name = "Collision_Spaceship_Background_A",
       Pos={0.000,0.000,0.000},Rot={0.000,0.000,0.000},Scl={1.000,1.000,1.000},
       Mesh = 2,
       Mat = 1,
      },
      {Name = "Geometry_Spaceship_Background_A_LOD00",
       Pos={0.000,0.000,0.000},Rot={270.000,0.000,0.000},Scl={1.000,1.000,1.000},
       Mesh = 2,
       Mat = 1,
      },
      {Name = "Geometry_Spaceship_Background_A_LOD01",
       Pos={0.000,0.000,0.000},Rot={270.000,0.000,0.000},Scl={1.000,1.000,1.000},
       Mesh = 2,
       Mat = 1,
      },
      {Name = "Geometry_Spaceship_Background_A_LOD02",
       Pos={0.000,0.000,0.000},Rot={270.000,0.000,0.000},Scl={1.000,1.000,1.000},
       Mesh = 2,
       Mat = 1,
      },
      {Name = "Geometry_Spaceship_Background_A_LOD03",
       Pos={0.000,0.000,0.000},Rot={270.000,0.000,0.000},Scl={1.000,1.000,1.000},
       Mesh = 2,
       Mat = 1,
      },
     },
    },
    {Name = "Directional Light",
     Pos={0.000,3.000,0.000},Rot={50.000,330.000,0.000},Scl={1.000,1.000,1.000},
    },
    {Name = "Main Camera",
     Pos={0.000,1.000,-10.000},Rot={0.000,0.000,0.000},Scl={1.000,1.000,1.000},
    },

   },
   Meshes = {
    [1]="Assets/Models/Environment/Vehicles/Spaceships/Spaceship_A/Spaceship_A_Crashed.fbx",
    [2]="Assets/Models/Environment/Vehicles/Spaceships/Spaceship_Background_A/Spaceship_Background_A.fbx",

   },
   Materials = {
    [1]="Resources/unity_builtin_extra",

   },
   Textures = {

   },
   SummaryInfo = {
    NumMeshes=2,
    NumMaterials=1,
    NumTextures=0,
   },

 },
-------- scene done -------

}
return World
