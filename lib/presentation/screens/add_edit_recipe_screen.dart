import 'dart:io';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/recipe_model.dart';
import '../../data/services/recipe_service.dart';

class AddEditRecipeScreen extends StatefulWidget {
  final RecipeModel? recipe;

  const AddEditRecipeScreen({super.key, this.recipe});

  @override
  State<AddEditRecipeScreen> createState() => _AddEditRecipeScreenState();
}

class _AddEditRecipeScreenState extends State<AddEditRecipeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _calController = TextEditingController();
  final _protController = TextEditingController();
  final _carbController = TextEditingController();
  final _fatController = TextEditingController();

  List<String> _ingredients = [];
  List<String> _instructions = [];
  File? _imageFile;
  final _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    if (widget.recipe != null) {
      _nameController.text = widget.recipe!.name;
      _descController.text = widget.recipe!.description;
      _ingredients = List.from(widget.recipe!.ingredients);
      _instructions = List.from(widget.recipe!.instructions);
      _calController.text = widget.recipe!.calories.toString();
      _protController.text = widget.recipe!.protein.toString();
      _carbController.text = widget.recipe!.carbs.toString();
      _fatController.text = widget.recipe!.fat.toString();
      if (widget.recipe!.localImagePath != null) {
        _imageFile = File(widget.recipe!.localImagePath!);
      }
    }
  }

  Future<void> _pickImage() async {
    final pickedFile = await _imagePicker.pickImage(source: ImageSource.gallery);
    // Elegir foto saca al usuario de la app: al volver, la pantalla puede
    // haberse desmontado.
    if (pickedFile != null && mounted) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  void _saveRecipe() async {
    if (_formKey.currentState!.validate()) {
      String? imagePath;
      if (_imageFile != null) {
        // Guardar la imagen localmente dentro de la app
        final appDirectory = await getApplicationDocumentsDirectory(); // Necesito importar path_provider
        final fileName = '${Uuid().v4()}.png';
        final localImage = await _imageFile!.copy('${appDirectory.path}/$fileName');
        imagePath = localImage.path;
      }

      final recipe = RecipeModel(
        id: widget.recipe?.id ?? const Uuid().v4(),
        name: _nameController.text,
        description: _descController.text,
        ingredients: _ingredients,
        instructions: _instructions,
        calories: int.parse(_calController.text),
        protein: double.parse(_protController.text),
        carbs: double.parse(_carbController.text),
        fat: double.parse(_fatController.text),
        localImagePath: imagePath,
        createdAt: widget.recipe?.createdAt ?? DateTime.now(),
      );

      await RecipeService().saveRecipe(recipe);
      if (mounted) Navigator.pop(context);
    }
  }

  Widget _buildListField({
    required String title,
    required List<String> list,
    required Function(String) onAddItem,
    required Function(int) onRemoveItem,
  }) {
    final controller = TextEditingController();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        ...list.asMap().entries.map((entry) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Expanded(child: Text('${entry.key + 1}. ${entry.value}', style: const TextStyle(color: AppColors.textSecondary))),
              IconButton(
                icon: const Icon(Icons.remove_circle_outline, color: AppColors.error),
                onPressed: () => onRemoveItem(entry.key),
              ),
            ],
          ),
        )),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                decoration: InputDecoration(
                  hintText: 'Añadir ${title.toLowerCase().substring(0, title.length -1)}',
                  hintStyle: const TextStyle(color: AppColors.textTertiary),
                ),
                style: const TextStyle(color: AppColors.textPrimary),
                onSubmitted: (value) {
                  if (value.trim().isNotEmpty) {
                    onAddItem(value);
                    controller.clear();
                  }
                },
              ),
            ),
               IconButton(
                 icon: const Icon(Icons.add_circle, color: AppColors.accent),
                 onPressed: () {

                if (controller.text.trim().isNotEmpty) {
                  onAddItem(controller.text);
                  controller.clear();
                }
              },
            ),
          ],
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.recipe == null ? 'Nueva Receta' : 'Editar Receta', style: const TextStyle(color: AppColors.textPrimary)),
        backgroundColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Selector de Imagen
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  height: 200,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.textPrimary.withValues(alpha: 0.1)),
                    image: _imageFile != null
                        ? DecorationImage(image: FileImage(_imageFile!), fit: BoxFit.cover)
                        : null,
                  ),
                  child: _imageFile == null
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.camera_alt, size: 50, color: AppColors.textPrimary.withValues(alpha: 0.3)),
                            const SizedBox(height: 10),
                            Text('Añadir imagen', style: TextStyle(color: AppColors.textPrimary.withValues(alpha: 0.5))),
                          ],
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 24),
              _buildTextField(_nameController, 'Nombre de la Receta', Icons.restaurant),
              const SizedBox(height: 16),
              _buildTextField(_descController, 'Descripción', Icons.description, maxLines: 3),
              const SizedBox(height: 16),
              
              // Ingredientes Dinámicos
              _buildListField(
                title: 'Ingredientes',
                list: _ingredients,
                onAddItem: (item) => setState(() => _ingredients.add(item)),
                onRemoveItem: (index) => setState(() => _ingredients.removeAt(index)),
              ),

              // Instrucciones Dinámicas
              _buildListField(
                title: 'Instrucciones',
                list: _instructions,
                onAddItem: (item) => setState(() => _instructions.add(item)),
                onRemoveItem: (index) => setState(() => _instructions.removeAt(index)),
              ),

              const Text('Información Nutricional', style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _buildNumberField(_calController, 'Kcal', Icons.local_fire_department)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildNumberField(_protController, 'Prot (g)', Icons.fitness_center)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _buildNumberField(_carbController, 'Carbos (g)', Icons.bakery_dining)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildNumberField(_fatController, 'Grasas (g)', Icons.opacity)),
                ],
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _saveRecipe,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: AppColors.background,
                  ),
                  child: const Text('Guardar Receta', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {int maxLines = 1}) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(color: AppColors.textPrimary),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: Theme.of(context).colorScheme.primary),
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.textSecondary),
      ),
      validator: (value) => value == null || value.isEmpty ? 'Campo requerido' : null,
    );
  }

  Widget _buildNumberField(TextEditingController controller, String label, IconData icon) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      style: const TextStyle(color: AppColors.textPrimary),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: Theme.of(context).colorScheme.primary, size: 20),
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.textSecondary),
      ),
      validator: (value) => value == null || value.isEmpty ? 'Req.' : null,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _calController.dispose();
    _protController.dispose();
    _carbController.dispose();
    _fatController.dispose();
    super.dispose();
  }
}
