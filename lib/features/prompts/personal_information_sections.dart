part of 'personal_information_screen.dart';

/// The three form sections of [_PersonalInformationScreenState].
extension _PersonalInformationSections on _PersonalInformationScreenState {
  Widget _aboutSection(BuildContext context, PromptConfig draft) {
    return _FormSection(
      key: _sectionKeys['about'],
      title: 'About you',
      icon: Icons.badge_outlined,
      missing: _missingIn('about', draft),
      expanded: _isExpanded('about', draft),
      onToggle: () => _toggleSection('about'),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  hintText: 'Your full name',
                ),
                onChanged: (_) => _update(() => _dirty = true),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _ageController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Age',
                  hintText: 'e.g. 28',
                ),
                onChanged: (_) => _update(() => _dirty = true),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _gender,
                decoration: const InputDecoration(labelText: 'Gender'),
                hint: const Text('Select gender'),
                items: const [
                  DropdownMenuItem(value: 'Male', child: Text('Male')),
                  DropdownMenuItem(value: 'Female', child: Text('Female')),
                ],
                onChanged: (value) => _update(() {
                  _gender = value;
                  _dirty = true;
                }),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _locationController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Location',
                  hintText: 'e.g. Dhaka, Bangladesh',
                ),
                onChanged: (_) => _update(() => _dirty = true),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _maritalStatus,
                decoration: const InputDecoration(labelText: 'Marital status'),
                hint: const Text('Select marital status'),
                items: const [
                  DropdownMenuItem(value: 'Single', child: Text('Single')),
                  DropdownMenuItem(
                    value: 'In a relationship',
                    child: Text('In a relationship'),
                  ),
                  DropdownMenuItem(value: 'Married', child: Text('Married')),
                  DropdownMenuItem(value: 'Divorced', child: Text('Divorced')),
                  DropdownMenuItem(value: 'Widowed', child: Text('Widowed')),
                ],
                onChanged: (value) => _update(() {
                  _maritalStatus = value;
                  _dirty = true;
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _professionSection(BuildContext context, PromptConfig draft) {
    final theme = Theme.of(context);
    return _FormSection(
      key: _sectionKeys['profession'],
      title: 'Profession and schedule',
      icon: Icons.work_outline,
      missing: _missingIn('profession', draft),
      expanded: _isExpanded('profession', draft),
      onToggle: () => _toggleSection('profession'),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<EmploymentStatus>(
                initialValue: _employmentStatus,
                decoration: const InputDecoration(labelText: 'Profession'),
                hint: const Text('Select your profession'),
                items: [
                  for (final status in EmploymentStatus.values)
                    DropdownMenuItem(
                      value: status,
                      child: Text(_employmentStatusLabel(status)),
                    ),
                ],
                onChanged: (value) => _update(() {
                  _employmentStatus = value;
                  _dirty = true;
                }),
              ),
              const SizedBox(height: 12),
              if (_employmentStatus == EmploymentStatus.working) ...[
                TextField(
                  controller: _jobTitleController,
                  decoration: const InputDecoration(
                    labelText: 'Job title',
                    hintText: 'e.g. Software Engineer L1',
                  ),
                  onChanged: (_) => _update(() => _dirty = true),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _employerController,
                  decoration: const InputDecoration(
                    labelText: 'Employer',
                    hintText: 'e.g. Catch Bangladesh LTD',
                  ),
                  onChanged: (_) => _update(() => _dirty = true),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _workAddressController,
                  minLines: 2,
                  maxLines: 3,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Work address',
                    hintText: 'e.g. 123 Main Road, Gulshan, Dhaka',
                    alignLabelWithHint: true,
                  ),
                  onChanged: (_) => _update(() => _dirty = true),
                ),
                const SizedBox(height: 12),
                WeekendDayPicker(
                  selectedWeekdays: _weekendDays,
                  helperText: 'Select the days you are off work.',
                  onChanged: (days) => _update(() {
                    _weekendDays = days;
                    _dirty = true;
                  }),
                ),
                const SizedBox(height: 12),
                TimeRangePickerField(
                  label: 'Work hours',
                  start: _workStart,
                  end: _workEnd,
                  helperText: 'Pick your usual start and end times.',
                  onChanged: (start, end) => _update(() {
                    _workStart = start;
                    _workEnd = end;
                    _dirty = true;
                  }),
                ),
              ] else if (_employmentStatus == EmploymentStatus.student) ...[
                TextField(
                  controller: _schoolNameController,
                  decoration: const InputDecoration(
                    labelText: 'School or university',
                    hintText: 'e.g. University of Dhaka',
                  ),
                  onChanged: (_) => _update(() => _dirty = true),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _studyProgramController,
                  decoration: const InputDecoration(
                    labelText: 'Program or major',
                    hintText: 'e.g. Computer Science',
                  ),
                  onChanged: (_) => _update(() => _dirty = true),
                ),
                const SizedBox(height: 12),
                WeekendDayPicker(
                  selectedWeekdays: _weekendDays,
                  helperText: 'Select the days you are off from classes.',
                  onChanged: (days) => _update(() {
                    _weekendDays = days;
                    _dirty = true;
                  }),
                ),
                const SizedBox(height: 12),
                TimeRangePickerField(
                  label: 'Study hours',
                  start: _studyStart,
                  end: _studyEnd,
                  helperText: 'Pick your usual class or study times.',
                  onChanged: (start, end) => _update(() {
                    _studyStart = start;
                    _studyEnd = end;
                    _dirty = true;
                  }),
                ),
              ] else if (_employmentStatus == EmploymentStatus.unemployed) ...[
                TextField(
                  controller: _unemploymentSituationController,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Current situation',
                    hintText: 'e.g. Job searching, career break, caregiving',
                    alignLabelWithHint: true,
                  ),
                  onChanged: (_) => _update(() => _dirty = true),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _routineDaysController,
                  decoration: const InputDecoration(
                    labelText: 'Typical days',
                    hintText: 'e.g. Monday to Saturday',
                  ),
                  onChanged: (_) => _update(() => _dirty = true),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _routineHoursController,
                  decoration: const InputDecoration(
                    labelText: 'Typical hours',
                    hintText: 'e.g. 8 AM to 10 PM',
                  ),
                  onChanged: (_) => _update(() => _dirty = true),
                ),
              ] else
                Text(
                  'Select a profession above to show the right fields.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _goalsSection(BuildContext context, PromptConfig draft) {
    return _FormSection(
      key: _sectionKeys['goals'],
      title: 'Goals and lifestyle',
      icon: Icons.flag_outlined,
      missing: _missingIn('goals', draft),
      expanded: _isExpanded('goals', draft),
      onToggle: () => _toggleSection('goals'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_employmentStatus == EmploymentStatus.working) ...[
                    TextField(
                      controller: _incomeController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Monthly income (BDT)',
                        hintText: 'e.g. 80000',
                      ),
                      onChanged: (_) => _update(() => _dirty = true),
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextField(
                    controller: _budgetController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Monthly budget (BDT)',
                      hintText: 'e.g. 50000',
                      helperText:
                          'Used for budget utilization, spending pace, and overrun calculations.',
                    ),
                    onChanged: (_) => _update(() => _dirty = true),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _financialController,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Financial rules',
                      hintText:
                          'Spending priorities, savings goals, and constraints',
                      alignLabelWithHint: true,
                    ),
                    onChanged: (_) => _update(() => _dirty = true),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _fitnessController,
                    minLines: 2,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: 'Fitness goal',
                      hintText:
                          'Body goal, activity target, recovery requirements',
                      alignLabelWithHint: true,
                    ),
                    onChanged: (_) => _update(() => _dirty = true),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _lifestyleController,
                    minLines: 2,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: 'Household and lifestyle',
                      hintText: 'Personal context that affects recommendations',
                      alignLabelWithHint: true,
                    ),
                    onChanged: (_) => _update(() => _dirty = true),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _rideController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Your ride (optional)',
                      hintText: 'e.g. Vespa Primavera 150, 2022',
                      helperText:
                          'Used to predict servicing and oil '
                          'changes from your bike’s usual '
                          'intervals.',
                      helperMaxLines: 2,
                    ),
                    onChanged: (_) => _update(() => _dirty = true),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _decisionSupportController,
                    minLines: 2,
                    maxLines: 6,
                    decoration: const InputDecoration(
                      labelText: 'Decision support rule',
                      hintText:
                          'How Buy/Skip or other verdicts should be handled',
                      alignLabelWithHint: true,
                    ),
                    onChanged: (_) => _update(() => _dirty = true),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: CrossDomainImpactPicker(
                selectedImpacts: _crossDomainImpacts,
                customImpacts: _customCrossDomainImpacts,
                onChanged:
                    ({required selectedImpacts, required customImpacts}) {
                      _update(() {
                        _crossDomainImpacts = selectedImpacts;
                        _customCrossDomainImpacts = customImpacts;
                        _dirty = true;
                      });
                    },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
