import 'package:aco_plus/app/core/client/firestore/collections/patio/models/patio_model.dart';
import 'package:aco_plus/app/core/client/firestore/firestore_client.dart';
import 'package:aco_plus/app/core/components/app_field.dart';
import 'package:aco_plus/app/core/components/empty_data.dart';
import 'package:aco_plus/app/core/components/stream_out.dart';
import 'package:aco_plus/app/core/utils/app_colors.dart';
import 'package:aco_plus/app/core/utils/app_css.dart';
import 'package:aco_plus/app/core/utils/global_resource.dart';
import 'package:aco_plus/app/modules/patio/patio_controller.dart';
import 'package:aco_plus/app/modules/patio/patio_view_model.dart';
import 'package:aco_plus/app/modules/patio/ui/patio_box_page.dart';
import 'package:aco_plus/app/modules/patio/ui/patio_create_page.dart';
import 'package:aco_plus/app/modules/patio/ui/patio_parque_page.dart';
import 'package:flutter/material.dart';

class PatioTabsPage extends StatefulWidget {
  const PatioTabsPage({super.key});

  @override
  State<PatioTabsPage> createState() => _PatioTabsPageState();
}

class _PatioTabsPageState extends State<PatioTabsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    setWebTitle('Pátios');
    _tabController = TabController(length: 3, vsync: this);
    patioCtrl.onInit();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: AppColors.primaryMain,
        elevation: 0,
        leading: IconButton(
          onPressed: () => pop(context),
          icon: Icon(Icons.arrow_back, color: AppColors.white),
        ),
        title: Text(
          'Cadastro de Pátio',
          style: AppCss.largeBold.setColor(AppColors.white),
        ),
        actions: [
          ListenableBuilder(
            listenable: _tabController,
            builder: (_, __) => _tabController.index == 0
                ? IconButton(
                    onPressed: () => push(context, const PatioCreatePage()),
                    icon: const Icon(Icons.add, color: Colors.white),
                    tooltip: 'Novo Pátio',
                  )
                : const SizedBox.shrink(),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Container(
            color: AppColors.primaryMain,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: TabBar(
                  controller: _tabController,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white60,
                  indicator: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.4),
                      width: 1,
                    ),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  labelStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                  ),
                  tabs: const [
                    Tab(
                      height: 36,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.grid_view_rounded, size: 16),
                          SizedBox(width: 6),
                          Text('Pátio'),
                        ],
                      ),
                    ),
                    Tab(
                      height: 36,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.dashboard_customize_rounded, size: 16),
                          SizedBox(width: 6),
                          Text('Box'),
                        ],
                      ),
                    ),
                    Tab(
                      height: 36,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.map_outlined, size: 16),
                          SizedBox(width: 6),
                          Text('Parque'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // Faixa separadora
          Container(
            height: 3,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1E40AF), Color(0xFF60A5FA)],
              ),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [
                _PatiosListTab(),
                PatioBoxPage(),
                PatioParquePage(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Aba 0: lista de pátios ──────────────────────────────────────────────────
class _PatiosListTab extends StatelessWidget {
  const _PatiosListTab();

  @override
  Widget build(BuildContext context) {
    return StreamOut<List<PatioModel>>(
      stream: FirestoreClient.patios.dataStream.listen,
      builder: (_, allPatios) => StreamOut<PatioUtils>(
        stream: patioCtrl.utilsStream.listen,
        builder: (_, utils) {
          final patios = patioCtrl
              .getPatiosFiltered(utils.search.text, allPatios)
              .toList();
          patios.sort(
              (a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()));
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: AppField(
                  hint: 'Pesquisar',
                  controller: utils.search,
                  suffixIcon: Icons.search,
                  onChanged: (_) => patioCtrl.utilsStream.update(),
                ),
              ),
              Expanded(
                child: patios.isEmpty
                    ? const EmptyData()
                    : ListView.builder(
                        itemCount: patios.length,
                        itemBuilder: (_, i) =>
                            _itemPatio(context, patios[i]),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _itemPatio(BuildContext context, PatioModel patio) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey[200]!, width: 1)),
      ),
      child: ListTile(
        onTap: () => push(context, PatioCreatePage(patio: patio)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.primaryMain.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.grid_view_rounded,
              color: AppColors.primaryMain, size: 18),
        ),
        title: Text(patio.nome, style: AppCss.mediumBold),
        subtitle: Text(
          '${patio.comprimento}m × ${patio.largura}m',
          style: AppCss.minimumRegular.setColor(AppColors.neutralMedium),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(Icons.edit_outlined, color: Colors.blue[600], size: 16),
              iconSize: 16,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              padding: EdgeInsets.zero,
              onPressed: () => push(context, PatioCreatePage(patio: patio)),
            ),
            const SizedBox(width: 6),
            IconButton(
              icon: Icon(Icons.delete_outline, color: Colors.red[600], size: 16),
              iconSize: 16,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              padding: EdgeInsets.zero,
              onPressed: () => patioCtrl.onDelete(context, patio),
            ),
          ],
        ),
      ),
    );
  }
}
